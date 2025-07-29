// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { IFusionPlus } from "./IFusionPlus.sol";

/**
 * @title EscrowSrc - Source escrow contract for Fusion+ cross-chain swaps
 * @notice Handles locking of source tokens for cross-chain swaps
 * @custom:security-contact security@1inch.io
 */
contract EscrowSrc is IFusionPlus, Ownable {
    using SafeERC20 for IERC20;

    // ===== State Variables =====

    mapping(bytes32 => IFusionPlus.EscrowStatus) public escrowStatuses;
    mapping(bytes32 => IFusionPlus.Immutables) public escrowImmutables;
    mapping(address => bool) public accessTokenHolders;
    uint256 public constant RESCUE_DELAY = 30 days;

    // ===== Modifiers =====

    modifier onlyAccessTokenHolder() {
        require(accessTokenHolders[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier onlyValidEscrow(bytes32 orderHash) {
        require(escrowStatuses[orderHash].deployedAt > 0, "Escrow not found");
        _;
    }

    modifier onlyNotFilled(bytes32 orderHash) {
        require(!escrowStatuses[orderHash].isFilled, "Escrow already filled");
        _;
    }

    modifier onlyNotCancelled(bytes32 orderHash) {
        require(!escrowStatuses[orderHash].isCancelled, "Escrow already cancelled");
        _;
    }

    modifier onlyTaker(bytes32 orderHash) {
        require(msg.sender == escrowImmutables[orderHash].taker, "Invalid caller");
        _;
    }

    modifier onlyValidSecret(bytes32 secret, bytes32 orderHash) {
        require(keccak256(abi.encodePacked(secret)) == escrowImmutables[orderHash].hashlock, "Invalid secret");
        _;
    }

    modifier onlyAfter(uint256 start) {
        require(block.timestamp >= start, "Too early");
        _;
    }

    modifier onlyBefore(uint256 stop) {
        require(block.timestamp < stop, "Too late");
        _;
    }

    // ===== Constructor =====

    constructor() Ownable(msg.sender) {}

    // ===== Core Functions =====

    /**
     * @notice Create a new source escrow
     * @param orderHash The hash of the order
     * @param immutables The immutable parameters
     */
    function createEscrowSrc(
        bytes32 orderHash,
        IFusionPlus.Immutables memory immutables
    ) external payable override {
        require(msg.value >= immutables.safetyDeposit, "Insufficient safety deposit");
        require(escrowStatuses[orderHash].deployedAt == 0, "Escrow already exists");
        require(immutables.amount > 0, "Invalid amount");
        require(immutables.safetyDeposit > 0, "Invalid safety deposit");

        // Validate timelocks
        require(immutables.timelocks.srcWithdrawal > 0, "Invalid timelock");
        require(immutables.timelocks.srcPublicWithdrawal > immutables.timelocks.srcWithdrawal, "Invalid timelock");
        require(immutables.timelocks.srcCancellation > immutables.timelocks.srcPublicWithdrawal, "Invalid timelock");

        // Create escrow
        escrowStatuses[orderHash] = IFusionPlus.EscrowStatus({
            isFilled: false,
            isCancelled: false,
            deployedAt: block.timestamp,
            filledAt: 0,
            cancelledAt: 0
        });

        // Store immutables
        escrowImmutables[orderHash] = immutables;

        emit EscrowCreated(orderHash, msg.sender, true);
    }

    /**
     * @notice Withdraw funds from escrow using secret
     * @param orderHash The hash of the order
     * @param secret The secret that unlocks the escrow
     * @return The amount withdrawn
     */
    function withdraw(
        bytes32 orderHash,
        bytes32 secret
    ) external override onlyValidEscrow(orderHash) onlyNotFilled(orderHash) onlyNotCancelled(orderHash) returns (uint256) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        require(immutables.hashlock == keccak256(abi.encodePacked(secret)), "Invalid secret");
        require(block.timestamp >= immutables.timelocks.srcWithdrawal, "Withdrawal not yet available");

        // Mark as filled
        escrowStatuses[orderHash].isFilled = true;

        // Transfer funds to taker
        uint256 amount = immutables.amount;
        payable(immutables.taker).transfer(amount);

        emit EscrowWithdrawn(orderHash, immutables.taker, amount);
        return amount;
    }

    /**
     * @notice Withdraw tokens to specific address (private)
     * @param orderHash The hash of the order
     * @param secret The secret that unlocks the escrow
     * @param target The address to transfer tokens to
     */
    function withdrawTo(
        bytes32 orderHash,
        bytes32 secret,
        address target
    ) external onlyTaker(orderHash) onlyValidEscrow(orderHash) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        IFusionPlus.EscrowStatus storage status = escrowStatuses[orderHash];

        // Validate timelock
        uint256 withdrawalStart = immutables.deployedAt + immutables.timelocks.srcWithdrawal;
        uint256 cancellationStart = immutables.deployedAt + immutables.timelocks.srcCancellation;
        
        require(block.timestamp >= withdrawalStart, "Withdrawal not yet available");
        require(block.timestamp < cancellationStart, "Withdrawal period expired");

        // Validate secret
        require(keccak256(abi.encodePacked(secret)) == immutables.hashlock, "Invalid secret");

        // Validate escrow not already filled or cancelled
        require(!status.isFilled, "Order already filled");
        require(!status.isCancelled, "Order already cancelled");

        // Mark as filled
        status.isFilled = true;
        status.filledAt = block.timestamp;

        // Transfer tokens to target
        if (immutables.token != address(0)) {
            IERC20(immutables.token).safeTransfer(target, immutables.amount);
        } else {
            payable(target).transfer(immutables.amount);
        }

        // Transfer safety deposit to caller
        payable(msg.sender).transfer(immutables.safetyDeposit);

        emit EscrowWithdrawn(orderHash, msg.sender, immutables.amount);
    }

    /**
     * @notice Public withdrawal after public withdrawal timelock
     * @param orderHash The hash of the order
     * @param secret The secret that unlocks the escrow
     * @return The amount withdrawn
     */
    function publicWithdraw(
        bytes32 orderHash,
        bytes32 secret
    ) external onlyValidEscrow(orderHash) onlyNotFilled(orderHash) onlyNotCancelled(orderHash) returns (uint256) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        require(immutables.hashlock == keccak256(abi.encodePacked(secret)), "Invalid secret");
        require(block.timestamp >= immutables.timelocks.srcPublicWithdrawal, "Public withdrawal not yet available");

        // Mark as filled
        escrowStatuses[orderHash].isFilled = true;

        // Transfer funds to taker
        uint256 amount = immutables.amount;
        payable(immutables.taker).transfer(amount);

        emit EscrowWithdrawn(orderHash, immutables.taker, amount);
        return amount;
    }

    /**
     * @notice Cancel escrow and return funds to maker
     * @param orderHash The hash of the order
     * @return The amount returned
     */
    function cancel(
        bytes32 orderHash
    ) external override onlyValidEscrow(orderHash) onlyNotFilled(orderHash) onlyNotCancelled(orderHash) returns (uint256) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        require(block.timestamp >= immutables.timelocks.srcCancellation, "Cancellation not yet available");

        // Mark as cancelled
        escrowStatuses[orderHash].isCancelled = true;

        // Return funds to maker
        uint256 amount = immutables.amount;
        payable(immutables.maker).transfer(amount);

        emit EscrowCancelled(orderHash, immutables.maker, amount);
        return amount;
    }

    /**
     * @notice Public cancellation of source escrow (anyone with access token)
     * @param orderHash The hash of the order
     */
    function publicCancel(
        bytes32 orderHash
    ) external onlyAccessTokenHolder onlyValidEscrow(orderHash) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        IFusionPlus.EscrowStatus storage status = escrowStatuses[orderHash];

        // Validate timelock
        uint256 publicCancellationStart = immutables.deployedAt + immutables.timelocks.srcPublicCancellation;
        require(block.timestamp >= publicCancellationStart, "Public cancellation not yet available");

        // Validate escrow not already filled or cancelled
        require(!status.isFilled, "Order already filled");
        require(!status.isCancelled, "Order already cancelled");

        // Mark as cancelled
        status.isCancelled = true;
        status.cancelledAt = block.timestamp;

        // Return tokens to maker
        if (immutables.token != address(0)) {
            IERC20(immutables.token).safeTransfer(immutables.maker, immutables.amount);
        } else {
            payable(immutables.maker).transfer(immutables.amount);
        }

        // Transfer safety deposit to caller
        payable(msg.sender).transfer(immutables.safetyDeposit);

        emit EscrowCancelled(orderHash, immutables.maker, immutables.amount);
    }

    /**
     * @notice Rescue funds after rescue delay
     * @param orderHash The hash of the order
     * @param token The token to rescue
     * @param amount The amount to rescue
     * @return The amount rescued
     */
    function rescueFunds(
        bytes32 orderHash,
        address token,
        uint256 amount
    ) external onlyValidEscrow(orderHash) onlyNotFilled(orderHash) onlyNotCancelled(orderHash) returns (uint256) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        require(msg.sender == immutables.taker, "Only taker can rescue funds");
        require(block.timestamp >= immutables.timelocks.srcCancellation + 30 days, "Rescue delay not met");

        // Mark as cancelled
        escrowStatuses[orderHash].isCancelled = true;

        // Transfer funds to taker
        if (token == address(0)) {
            payable(immutables.taker).transfer(amount);
        } else {
            IERC20(token).safeTransfer(immutables.taker, amount);
        }

        emit EscrowCancelled(orderHash, immutables.taker, amount);
        return amount;
    }

    // ===== Admin Functions =====

    /**
     * @notice Add access token holder
     * @param holder The address to add
     */
    function addAccessTokenHolder(address holder) external onlyOwner {
        accessTokenHolders[holder] = true;
    }

    /**
     * @notice Remove access token holder
     * @param holder The address to remove
     */
    function removeAccessTokenHolder(address holder) external onlyOwner {
        accessTokenHolders[holder] = false;
    }

    // ===== View Functions =====

    /**
     * @notice Get escrow status
     * @param orderHash The hash of the order
     * @return The escrow status
     */
    function getEscrowStatus(bytes32 orderHash) external view returns (IFusionPlus.EscrowStatus memory) {
        return escrowStatuses[orderHash];
    }

    /**
     * @notice Get escrow immutables
     * @param orderHash The hash of the order
     * @return The escrow immutables
     */
    function getEscrowImmutables(bytes32 orderHash) external view returns (IFusionPlus.Immutables memory) {
        return escrowImmutables[orderHash];
    }

    /**
     * @notice Check if address is access token holder
     * @param holder The address to check
     * @return True if holder has access
     */
    function hasAccessToken(address holder) external view returns (bool) {
        return accessTokenHolders[holder];
    }

    /**
     * @notice Get current stage of escrow
     * @param orderHash The hash of the order
     * @return The current stage (0-4)
     */
    function getEscrowStage(bytes32 orderHash) external view returns (uint8) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        uint256 currentTime = block.timestamp;
        uint256 deployedAt = immutables.deployedAt;
        IFusionPlus.Timelocks storage timelocks = immutables.timelocks;

        if (currentTime < deployedAt + timelocks.srcWithdrawal) {
            return 0; // Before withdrawal
        } else if (currentTime < deployedAt + timelocks.srcPublicWithdrawal) {
            return 1; // Private withdrawal
        } else if (currentTime < deployedAt + timelocks.srcCancellation) {
            return 2; // Public withdrawal
        } else if (currentTime < deployedAt + timelocks.srcPublicCancellation) {
            return 3; // Private cancellation
        } else {
            return 4; // Public cancellation
        }
    }

    // ===== Interface Functions =====

    /**
     * @notice Create destination escrow (not implemented in source escrow)
     */
    function createEscrowDst(
        bytes32 /* orderHash */,
        IFusionPlus.Immutables memory /* immutables */
    ) external payable override {
        revert("Not implemented in source escrow");
    }

    // ===== Dutch Auction Functions (Stubs) =====

    /**
     * @notice Start Dutch auction (not implemented in escrow)
     */
    function startAuction(
        bytes32 /* orderHash */,
        IFusionPlus.AuctionDetails memory /* auctionDetails */
    ) external pure override {
        revert("Not implemented in escrow");
    }

    /**
     * @notice Get current auction rate (not implemented in escrow)
     */
    function getCurrentRate(bytes32 /* orderHash */) external pure override returns (uint256) {
        revert("Not implemented in escrow");
    }

    /**
     * @notice Fill order (not implemented in escrow)
     */
    function fillOrder(
        bytes32 /* orderHash */,
        uint256 /* fillAmount */,
        bytes32 /* secret */
    ) external payable override returns (uint256) {
        revert("Not implemented in escrow");
    }

    /**
     * @notice Check if auction is active (not implemented in escrow)
     */
    function isAuctionActive(bytes32 /* orderHash */) external pure override returns (bool) {
        revert("Not implemented in escrow");
    }

    // ===== Receive Function =====

    receive() external payable {}
} 