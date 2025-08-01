// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOrderMixin} from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {TakerTraits} from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import {IResolverExample} from "cross-chain-swap/interfaces/IResolverExample.sol";
import {RevertReasonForwarder} from "solidity-utils/contracts/libraries/RevertReasonForwarder.sol";
import {IEscrowFactory} from "cross-chain-swap/interfaces/IEscrowFactory.sol";
import {IBaseEscrow} from "cross-chain-swap/interfaces/IBaseEscrow.sol";
import {TimelocksLib, Timelocks} from "cross-chain-swap/libraries/TimelocksLib.sol";
import {Address} from "solidity-utils/contracts/libraries/AddressLib.sol";
import {IEscrow} from "cross-chain-swap/interfaces/IEscrow.sol";
import {ImmutablesLib} from "cross-chain-swap/libraries/ImmutablesLib.sol";

/**
 * @title SuiResolver - Gas-free cross-chain swaps between Ethereum and Sui
 * @dev Implements 1inch Fusion+ pattern where resolvers pay gas, not users
 * @dev Users create orders off-chain, resolvers call deploySrc/deployDst to fill them
 */
contract SuiResolver is IResolverExample, Ownable {
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;

    error InvalidAmount();
    error SwapNotFound();
    error SwapAlreadyCompleted();
    error SwapAlreadyCancelled();
    error SwapExpired();
    error InvalidSecret();

    // Constants
    uint256 public constant SUI_CHAIN_ID = 21;
    uint256 public constant MIN_SUI_AMOUNT = 0.001 ether;

    // Events
    event SuiSwapInitiated(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        uint256 amount,
        bytes32 secretHash,
        uint256 timelock
    );
    event SuiSwapCompleted(bytes32 indexed orderHash, bytes32 secret, uint256 amount);
    event SuiSwapCancelled(bytes32 indexed orderHash, address indexed canceller);

    // Structs
    struct SuiSwap {
        address maker;
        address taker;
        uint256 amount;
        bytes32 secretHash;
        uint256 timelock;
        bool completed;
        bool cancelled;
        uint256 createdAt;
    }

    // State variables
    mapping(bytes32 => SuiSwap) public suiSwaps;
    IEscrowFactory public immutable escrowFactory;
    IOrderMixin public immutable limitOrderProtocol;
    address public relayer;

    // Modifiers
    modifier onlyRelayer() {
        require(msg.sender == relayer, "Only relayer");
        _;
    }

    modifier onlyValidAmount(uint256 amount) {
        require(amount >= MIN_SUI_AMOUNT, "Amount too small");
        _;
    }

    constructor(
        IEscrowFactory _escrowFactory,
        IOrderMixin _limitOrderProtocol,
        address initialOwner
    ) Ownable(initialOwner) {
        escrowFactory = _escrowFactory;
        limitOrderProtocol = _limitOrderProtocol;
    }

    receive() external payable {} // solhint-disable-line no-empty-blocks

    /**
     * @notice Deploy source escrow for Ethereum to Sui swap (RESOLVER PAYS GAS)
     * @dev This is called by resolvers who compete in Dutch auction
     * @dev Resolver pays gas, user gets gas-free swap
     * @dev User creates order off-chain, resolver calls this to fill it
     */
    function deploySrc(
        IBaseEscrow.Immutables calldata immutables,
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external payable override onlyValidAmount(amount) {
        
        // Update timelocks with current deployment time
        IBaseEscrow.Immutables memory immutablesMem = immutables;
        immutablesMem.timelocks = TimelocksLib.setDeployedAt(immutables.timelocks, block.timestamp);
        
        // Calculate escrow address and send safety deposit
        address computed = escrowFactory.addressOfEscrowSrc(immutablesMem);
        
        // Ensure we have enough value sent to cover the safety deposit
        uint256 safetyDeposit = immutablesMem.safetyDeposit;
        require(msg.value >= safetyDeposit, "Insufficient value sent for safety deposit");
        
        (bool success,) = computed.call{value: safetyDeposit}("");
        if (!success) revert IBaseEscrow.NativeTokenSendingFailure();
        
        // Return excess ETH to sender if any
        if (msg.value > safetyDeposit) {
            (bool refundSuccess,) = msg.sender.call{value: msg.value - safetyDeposit}("");
            require(refundSuccess, "Refund failed");
        }

        // Set target flag for cross-chain swap
        // _ARGS_HAS_TARGET = 1 << 251
        takerTraits = TakerTraits.wrap(TakerTraits.unwrap(takerTraits) | uint256(1 << 251));
        bytes memory argsMem = abi.encodePacked(computed, args);
        
        // Fill the order (RESOLVER PAYS GAS HERE)
        limitOrderProtocol.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);
        
        // Record the Sui swap for our cross-chain coordination
        suiSwaps[immutables.orderHash] = SuiSwap({
            maker: address(uint160(Address.unwrap(immutables.maker))),
            taker: address(uint160(Address.unwrap(immutables.taker))),
            amount: amount,
            secretHash: immutables.hashlock,
            timelock: immutablesMem.timelocks.get(TimelocksLib.Stage.SrcCancellation),
            completed: false,
            cancelled: false,
            createdAt: block.timestamp
        });
        
        emit SuiSwapInitiated(
            immutables.orderHash,
            address(uint160(Address.unwrap(immutables.maker))),
            address(uint160(Address.unwrap(immutables.taker))),
            amount,
            immutables.hashlock,
            immutables.timelocks.get(TimelocksLib.Stage.SrcCancellation)
        );
    }

    /**
     * @notice Deploy destination escrow for Sui to Ethereum swap (RESOLVER PAYS GAS)
     * @dev This is called by resolvers who compete in Dutch auction
     * @dev Resolver pays gas, user gets gas-free swap
     * @dev User creates order off-chain, resolver calls this to fill it
     */
    function deployDst(
        IBaseEscrow.Immutables calldata dstImmutables,
        uint256 srcCancellationTimestamp
    ) external payable override {
        // Update timelocks with current deployment time
        IBaseEscrow.Immutables memory dstImmutablesMem = dstImmutables;
        dstImmutablesMem.timelocks = TimelocksLib.setDeployedAt(dstImmutables.timelocks, block.timestamp);
        
        // Deploy the destination escrow (RESOLVER PAYS GAS HERE)
        escrowFactory.createDstEscrow{value: msg.value}(dstImmutablesMem, srcCancellationTimestamp);
        
        // Record the Sui swap for our cross-chain coordination
        suiSwaps[dstImmutables.orderHash] = SuiSwap({
            maker: address(uint160(Address.unwrap(dstImmutablesMem.maker))),
            taker: address(uint160(Address.unwrap(dstImmutablesMem.taker))),
            amount: dstImmutablesMem.amount,
            secretHash: dstImmutablesMem.hashlock,
            timelock: dstImmutablesMem.timelocks.get(TimelocksLib.Stage.DstCancellation),
            completed: false,
            cancelled: false,
            createdAt: block.timestamp
        });
        
        emit SuiSwapInitiated(
            dstImmutablesMem.orderHash,
            address(uint160(Address.unwrap(dstImmutablesMem.maker))),
            address(uint160(Address.unwrap(dstImmutablesMem.taker))),
            dstImmutablesMem.amount,
            dstImmutablesMem.hashlock,
            dstImmutablesMem.timelocks.get(TimelocksLib.Stage.DstCancellation)
        );
    }

    /**
     * @notice Complete a Sui swap by providing the secret
     * @param orderHash The order hash of the swap
     * @param secret The secret that unlocks the escrow
     */
    function completeSuiSwap(bytes32 orderHash, bytes32 secret) external onlyRelayer {
        SuiSwap storage swap = suiSwaps[orderHash];
        if (swap.maker == address(0)) revert SwapNotFound();
        if (swap.completed) revert SwapAlreadyCompleted();
        if (swap.cancelled) revert SwapAlreadyCancelled();
        
        // Verify the secret matches the hashlock
        if (keccak256(abi.encodePacked(secret)) != swap.secretHash) revert InvalidSecret();
        
        // Mark as completed
        swap.completed = true;
        
        emit SuiSwapCompleted(orderHash, secret, swap.amount);
    }

    /**
     * @notice Cancel a Sui swap
     * @param orderHash The order hash of the swap
     */
    function cancelSuiSwap(bytes32 orderHash) external {
        SuiSwap storage swap = suiSwaps[orderHash];
        if (swap.maker == address(0)) revert SwapNotFound();
        if (swap.completed) revert SwapAlreadyCompleted();
        if (swap.cancelled) revert SwapAlreadyCancelled();
        
        // Check authorization and timelock
        bool isRelayer = msg.sender == relayer;
        bool isAuthorizedParty = msg.sender == swap.maker || msg.sender == swap.taker;
        bool isAfterTimelock = block.timestamp >= swap.timelock;
        
        require(
            isRelayer || (isAuthorizedParty && isAfterTimelock),
            "Not authorized"
        );
        
        swap.cancelled = true;
        
        emit SuiSwapCancelled(orderHash, msg.sender);
    }

    /**
     * @notice Set the relayer address
     * @param _relayer The new relayer address
     */
    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
    }

    /**
     * @notice Get Sui swap details
     * @param orderHash The order hash
     * @return The swap details
     */
    function getSuiSwap(bytes32 orderHash) external view returns (SuiSwap memory) {
        return suiSwaps[orderHash];
    }

    /**
     * @notice Check if a Sui swap is active
     * @param orderHash The order hash
     * @return True if active
     */
    function isSuiSwapActive(bytes32 orderHash) external view returns (bool) {
        SuiSwap memory swap = suiSwaps[orderHash];
        return swap.maker != address(0) && !swap.completed && !swap.cancelled && block.timestamp < swap.timelock;
    }

    /**
     * @notice Make arbitrary calls (emergency function)
     * @param targets Array of target addresses
     * @param arguments Array of call data
     */
    function arbitraryCalls(
        address[] calldata targets,
        bytes[] calldata arguments
    ) external onlyOwner {
        uint256 length = targets.length;
        if (targets.length != arguments.length) revert LengthMismatch();
        for (uint256 i = 0; i < length; ++i) {
            (bool success,) = targets[i].call(arguments[i]);
            if (!success) RevertReasonForwarder.reRevert();
        }
    }

    /**
     * @notice Rescue tokens stuck in contract
     * @param token The token address
     * @param to The recipient address
     * @param amount The amount to rescue
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    /**
     * @notice Rescue ETH stuck in contract
     * @param to The recipient address
     * @param amount The amount to rescue
     */
    function rescueETH(address to, uint256 amount) external onlyOwner {
        (bool success,) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
} 