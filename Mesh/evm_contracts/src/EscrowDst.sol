// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { IFusionPlus } from "./IFusionPlus.sol";

/**
 * @title EscrowDst - Destination escrow contract for Fusion+ cross-chain swaps
 * @notice Handles locking of destination tokens for cross-chain swaps
 * @custom:security-contact security@1inch.io
 */
contract EscrowDst is IFusionPlus, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ===== State Variables =====

    mapping(bytes32 => IFusionPlus.EscrowStatus) public escrowStatuses;
    mapping(bytes32 => IFusionPlus.Immutables) public escrowImmutables;
    mapping(address => bool) public accessTokenHolders;
    mapping(bytes32 => bool) public usedSecrets; // Prevent secret reuse
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

    // ===== Constructor =====

    constructor() Ownable(msg.sender) {}

    // ===== Core Functions =====

    /**
     * @notice Create a new destination escrow
     * @param orderHash The hash of the order
     * @param immutables The immutable parameters
     */
    function createEscrowDst(
        bytes32 orderHash,
        IFusionPlus.Immutables memory immutables
    ) external payable override nonReentrant {
        require(msg.value >= immutables.safetyDeposit, "Insufficient safety deposit");
        require(escrowStatuses[orderHash].deployedAt == 0, "Escrow already exists");
        require(immutables.amount > 0, "Invalid amount");
        require(immutables.safetyDeposit > 0, "Invalid safety deposit");

        // Validate timelocks
        require(immutables.timelocks.dstWithdrawal > 0, "Invalid timelock");
        require(immutables.timelocks.dstPublicWithdrawal > immutables.timelocks.dstWithdrawal, "Invalid timelock");
        require(immutables.timelocks.dstCancellation > immutables.timelocks.dstPublicWithdrawal, "Invalid timelock");

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

        emit EscrowCreated(orderHash, msg.sender, false);
    }

    /**
     * @notice Withdraw tokens from destination escrow (private)
     * @param orderHash The hash of the order
     * @param secret The secret that unlocks the escrow
     */
    function withdraw(
        bytes32 orderHash,
        bytes32 secret
    ) external override onlyTaker(orderHash) onlyValidEscrow(orderHash) nonReentrant returns (uint256) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        IFusionPlus.EscrowStatus storage status = escrowStatuses[orderHash];

        // Validate timelock
        uint256 withdrawalStart = immutables.deployedAt + immutables.timelocks.dstWithdrawal;
        uint256 cancellationStart = immutables.deployedAt + immutables.timelocks.dstCancellation;
        
        require(block.timestamp >= withdrawalStart, "Withdrawal not yet available");
        require(block.timestamp < cancellationStart, "Withdrawal period expired");

        // Validate secret
        require(keccak256(abi.encodePacked(secret)) == immutables.hashlock, "Invalid secret");
        require(!usedSecrets[secret], "Secret already used");
        
        // Mark secret as used
        usedSecrets[secret] = true;

        // Validate escrow not already filled or cancelled
        require(!status.isFilled, "Order already filled");
        require(!status.isCancelled, "Order already cancelled");

        // Mark as filled
        status.isFilled = true;
        status.filledAt = block.timestamp;

        // Transfer tokens to maker
        if (immutables.token != address(0)) {
            IERC20(immutables.token).safeTransfer(immutables.maker, immutables.amount);
        } else {
            payable(immutables.maker).transfer(immutables.amount);
        }

        // Transfer safety deposit to caller
        payable(msg.sender).transfer(immutables.safetyDeposit);

        emit EscrowWithdrawn(orderHash, msg.sender, immutables.amount);
        return immutables.amount;
    }

    /**
     * @notice Public withdrawal from destination escrow (anyone with access token)
     * @param orderHash The hash of the order
     * @param secret The secret that unlocks the escrow
     */
    function publicWithdraw(
        bytes32 orderHash,
        bytes32 secret
    ) external onlyAccessTokenHolder onlyValidEscrow(orderHash) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        IFusionPlus.EscrowStatus storage status = escrowStatuses[orderHash];

        // Validate timelock
        uint256 publicWithdrawalStart = immutables.deployedAt + immutables.timelocks.dstPublicWithdrawal;
        uint256 cancellationStart = immutables.deployedAt + immutables.timelocks.dstCancellation;
        
        require(block.timestamp >= publicWithdrawalStart, "Public withdrawal not yet available");
        require(block.timestamp < cancellationStart, "Public withdrawal period expired");

        // Validate secret
        require(keccak256(abi.encodePacked(secret)) == immutables.hashlock, "Invalid secret");

        // Validate escrow not already filled or cancelled
        require(!status.isFilled, "Order already filled");
        require(!status.isCancelled, "Order already cancelled");

        // Mark as filled
        status.isFilled = true;
        status.filledAt = block.timestamp;

        // Transfer tokens to maker
        if (immutables.token != address(0)) {
            IERC20(immutables.token).safeTransfer(immutables.maker, immutables.amount);
        } else {
            payable(immutables.maker).transfer(immutables.amount);
        }

        // Transfer safety deposit to caller
        payable(msg.sender).transfer(immutables.safetyDeposit);

        emit EscrowWithdrawn(orderHash, msg.sender, immutables.amount);
    }

    /**
     * @notice Cancel destination escrow (private)
     * @param orderHash The hash of the order
     */
    function cancel(
        bytes32 orderHash
    ) external override onlyTaker(orderHash) onlyValidEscrow(orderHash) returns (uint256) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        IFusionPlus.EscrowStatus storage status = escrowStatuses[orderHash];

        // Validate timelock
        uint256 cancellationStart = immutables.deployedAt + immutables.timelocks.dstCancellation;
        require(block.timestamp >= cancellationStart, "Cancellation not yet available");

        // Validate escrow not already filled or cancelled
        require(!status.isFilled, "Order already filled");
        require(!status.isCancelled, "Order already cancelled");

        // Mark as cancelled
        status.isCancelled = true;
        status.cancelledAt = block.timestamp;

        // Return tokens to taker
        if (immutables.token != address(0)) {
            IERC20(immutables.token).safeTransfer(immutables.taker, immutables.amount);
        } else {
            payable(immutables.taker).transfer(immutables.amount);
        }

        // Transfer safety deposit to caller
        payable(msg.sender).transfer(immutables.safetyDeposit);

        emit EscrowCancelled(orderHash, msg.sender, immutables.amount);
        return immutables.amount;
    }

    /**
     * @notice Rescue funds from escrow (after rescue delay)
     * @param orderHash The hash of the order
     * @param token The token to rescue
     * @param amount The amount to rescue
     */
    function rescueFunds(
        bytes32 orderHash,
        address token,
        uint256 amount
    ) external onlyTaker(orderHash) onlyValidEscrow(orderHash) {
        IFusionPlus.Immutables storage immutables = escrowImmutables[orderHash];
        
        // Validate rescue delay
        uint256 rescueStart = immutables.deployedAt + RESCUE_DELAY;
        require(block.timestamp >= rescueStart, "Rescue not yet available");

        if (token != address(0)) {
            IERC20(token).safeTransfer(msg.sender, amount);
        } else {
            payable(msg.sender).transfer(amount);
        }

        emit EscrowCancelled(orderHash, msg.sender, amount);
    }

    // ===== Admin Functions =====

    /**
     * @notice Add access token holder
     * @param holder The address to add as access token holder
     */
    function addAccessTokenHolder(address holder) external onlyOwner {
        accessTokenHolders[holder] = true;
    }

    /**
     * @notice Remove access token holder
     * @param holder The address to remove as access token holder
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
     * @notice Check if address has access token
     * @param addr The address to check
     * @return True if address has access token
     */
    function hasAccessToken(address addr) external view returns (bool) {
        return accessTokenHolders[addr];
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

        if (currentTime < deployedAt + timelocks.dstWithdrawal) {
            return 0; // Before withdrawal
        } else if (currentTime < deployedAt + timelocks.dstPublicWithdrawal) {
            return 1; // Private withdrawal
        } else if (currentTime < deployedAt + timelocks.dstCancellation) {
            return 2; // Public withdrawal
        } else {
            return 3; // Cancellation
        }
    }

    /**
     * @notice Check if a secret has been used
     * @param secret The secret to check
     * @return True if secret has been used
     */
    function isSecretUsed(bytes32 secret) external view returns (bool) {
        return usedSecrets[secret];
    }

    /**
     * @notice Verify if a secret matches a hash lock
     * @param secret The secret to verify
     * @param hashLock The hash lock to verify against
     * @return True if secret matches hash lock
     */
    function verifySecret(bytes32 secret, bytes32 hashLock) external pure returns (bool) {
        return keccak256(abi.encodePacked(secret)) == hashLock;
    }

    /**
     * @notice Create a hash lock from a secret
     * @param secret The secret to hash
     * @return The resulting hash lock
     */
    function createHashLock(bytes32 secret) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret));
    }

    // ===== Interface Functions =====

    /**
     * @notice Create source escrow (not implemented in destination escrow)
     */
    function createEscrowSrc(
        bytes32 /* orderHash */,
        IFusionPlus.Immutables memory /* immutables */
    ) external payable override {
        revert("Not implemented in destination escrow");
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