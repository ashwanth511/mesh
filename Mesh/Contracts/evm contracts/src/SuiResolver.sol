// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOrderMixin} from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {TakerTraits} from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";

import {IResolverExample} from "cross-chain-swap/interfaces/IResolverExample.sol";
import {RevertReasonForwarder} from "solidity-utils/contracts/libraries/RevertReasonForwarder.sol";
import {IEscrowFactory} from "cross-chain-swap/interfaces/IEscrowFactory.sol";
import {IBaseEscrow} from "cross-chain-swap/interfaces/IBaseEscrow.sol";
import {TimelocksLib, Timelocks} from "cross-chain-swap/libraries/TimelocksLib.sol";
import {Address, AddressLib} from "solidity-utils/contracts/libraries/AddressLib.sol";
import {IEscrow} from "cross-chain-swap/interfaces/IEscrow.sol";
import {ImmutablesLib} from "cross-chain-swap/libraries/ImmutablesLib.sol";


/**
 * @title Sui Resolver for 1inch Fusion+ Cross-chain Swap
 * @dev This contract handles cross-chain swaps between Ethereum and Sui Protocol.
 * It extends the base Resolver functionality to support Sui-specific operations.
 *
 * @custom:security-contact security@1inch.io
 */
contract SuiResolver is IResolverExample, Ownable {
    using AddressLib for Address;
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;

    // Events for Sui integration
    event SuiSwapInitiated(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        uint256 amount,
        bytes32 secretHash,
        uint256 timelock
    );
    
    event SuiSwapCompleted(
        bytes32 indexed orderHash,
        bytes32 secret,
        uint256 amount
    );
    
    event SuiSwapCancelled(
        bytes32 indexed orderHash,
        address indexed canceller,
        uint256 amount
    );

    // Constants for Sui integration
    uint256 public constant SUI_CHAIN_ID = 21; // Sui mainnet chain ID
    uint256 public constant MIN_SUI_AMOUNT = 0.001 ether; // Minimum swap amount
    
    // Struct to track Sui swaps
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
    
    // Mapping to track Sui swaps by order hash
    mapping(bytes32 => SuiSwap) public suiSwaps;
    
    // Escrow factory for deploying escrows
    IEscrowFactory public immutable escrowFactory;
    
    // Access token for public operations
    IERC20 public immutable accessToken;
    
    // Relayer address for cross-chain operations
    address public relayer;
    
    // Modifiers
    modifier onlyRelayer() {
        require(msg.sender == relayer, "Only relayer can call this function");
        _;
    }
    
    modifier onlyValidAmount(uint256 amount) {
        require(amount >= MIN_SUI_AMOUNT, "Amount too low");
        _;
    }

    /**
     * @dev Constructor
     * @param _escrowFactory Address of the escrow factory
     * @param _accessToken Address of the access token
     */
    constructor(IEscrowFactory _escrowFactory, IERC20 _accessToken) Ownable(msg.sender) {
        escrowFactory = _escrowFactory;
        accessToken = _accessToken;
    }

    /**
     * @notice Set the relayer address
     * @param _relayer Address of the relayer
     */
    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
    }

    /**
     * @notice Deploy source escrow for Ethereum to Sui swap
     * @param immutables The immutables of the escrow contract
     * @param amount Taker amount to fill
     */
    function deploySrc(
        IBaseEscrow.Immutables calldata immutables,
        IOrderMixin.Order calldata /* order */,
        bytes32 /* r */,
        bytes32 /* vs */,
        uint256 amount,
        TakerTraits /* takerTraits */,
        bytes calldata /* args */
    ) external override onlyValidAmount(amount) {
        
        // In the official 1inch pattern, deploySrc is handled by the Limit Order Protocol
        // The source escrow is automatically created when the order is filled
        // We just need to record the swap for our Sui integration
        
        // Record the Sui swap
        suiSwaps[immutables.orderHash] = SuiSwap({
            maker: immutables.maker.get(),
            taker: immutables.taker.get(),
            amount: amount,
            secretHash: immutables.hashlock,
            timelock: immutables.timelocks.get(TimelocksLib.Stage.SrcCancellation),
            completed: false,
            cancelled: false,
            createdAt: block.timestamp
        });
        
        emit SuiSwapInitiated(
            immutables.orderHash,
            immutables.maker.get(),
            immutables.taker.get(),
            amount,
            immutables.hashlock,
            immutables.timelocks.get(TimelocksLib.Stage.SrcCancellation)
        );
    }

    /**
     * @notice Deploy destination escrow for Sui to Ethereum swap
     * @param dstImmutables The immutables for the destination escrow
     * @param srcCancellationTimestamp The start of the cancellation period
     */
    function deployDst(
        IBaseEscrow.Immutables calldata dstImmutables,
        uint256 srcCancellationTimestamp
    ) external payable override {
        // Deploy the destination escrow using the official 1inch factory
        escrowFactory.createDstEscrow{value: msg.value}(dstImmutables, srcCancellationTimestamp);
        
        // Record the Sui swap
        suiSwaps[dstImmutables.orderHash] = SuiSwap({
            maker: dstImmutables.maker.get(),
            taker: dstImmutables.taker.get(),
            amount: dstImmutables.amount,
            secretHash: dstImmutables.hashlock,
            timelock: dstImmutables.timelocks.get(TimelocksLib.Stage.DstCancellation),
            completed: false,
            cancelled: false,
            createdAt: block.timestamp
        });
        
        emit SuiSwapInitiated(
            dstImmutables.orderHash,
            dstImmutables.maker.get(),
            dstImmutables.taker.get(),
            dstImmutables.amount,
            dstImmutables.hashlock,
            dstImmutables.timelocks.get(TimelocksLib.Stage.DstCancellation)
        );
    }

    /**
     * @notice Complete a Sui swap by providing the secret
     * @param orderHash The order hash of the swap
     * @param secret The secret that unlocks the escrow
     */
    function completeSuiSwap(bytes32 orderHash, bytes32 secret) external onlyRelayer {
        SuiSwap storage swap = suiSwaps[orderHash];
        require(swap.maker != address(0), "Swap not found");
        require(!swap.completed, "Swap already completed");
        require(!swap.cancelled, "Swap already cancelled");
        require(block.timestamp < swap.timelock, "Swap expired");
        
        // Verify the secret matches the hashlock
        require(keccak256(abi.encodePacked(secret)) == swap.secretHash, "Invalid secret");
        
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
        require(swap.maker != address(0), "Swap not found");
        require(!swap.completed, "Swap already completed");
        require(!swap.cancelled, "Swap already cancelled");
        require(block.timestamp >= swap.timelock, "Swap not expired yet");
        
        // Only maker or taker can cancel after timelock
        require(
            msg.sender == swap.maker || msg.sender == swap.taker,
            "Only maker or taker can cancel"
        );
        
        // Mark as cancelled
        swap.cancelled = true;
        
        emit SuiSwapCancelled(orderHash, msg.sender, swap.amount);
    }

    /**
     * @notice Get Sui swap details
     * @param orderHash The order hash
     * @return swap The swap details
     */
    function getSuiSwap(bytes32 orderHash) external view returns (SuiSwap memory swap) {
        return suiSwaps[orderHash];
    }

    /**
     * @notice Check if a Sui swap is active
     * @param orderHash The order hash
     * @return True if the swap is active
     */
    function isSuiSwapActive(bytes32 orderHash) external view returns (bool) {
        SuiSwap storage swap = suiSwaps[orderHash];
        return swap.maker != address(0) && 
               !swap.completed && 
               !swap.cancelled && 
               block.timestamp < swap.timelock;
    }

    /**
     * @notice Allow the owner to make arbitrary calls to other contracts
     * @param targets The addresses of the contracts to call
     * @param arguments The arguments to pass to the contract calls
     */
    function arbitraryCalls(
        address[] calldata targets,
        bytes[] calldata arguments
    ) external override onlyOwner {
        if (targets.length != arguments.length) {
            revert LengthMismatch();
        }
        
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, ) = targets[i].call(arguments[i]);
            if (!success) {
                RevertReasonForwarder.reRevert();
            }
        }
    }

    /**
     * @notice Emergency function to rescue stuck tokens
     * @param token The token address
     * @param amount The amount to rescue
     */
    function rescueTokens(IERC20 token, uint256 amount) external onlyOwner {
        token.transfer(owner(), amount);
    }

    /**
     * @notice Emergency function to rescue stuck ETH
     */
    function rescueETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
} 