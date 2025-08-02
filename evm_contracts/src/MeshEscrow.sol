// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title MeshEscrow
 * @dev Cross-chain escrow contract for Ethereum side of atomic swaps
 * Uses Hash-Time Lock Contract (HTLC) pattern for secure atomic swaps
 * Supports both WETH and native ETH for maximum flexibility
 */
contract MeshEscrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    
    // WETH contract address
    IERC20 public immutable weth;
    
    // Structs
    struct Escrow {
        address payable maker;
        address payable taker; // Optional: can be address(0) for open fills
        uint256 totalAmount;
        uint256 remainingAmount;
        bytes32 hashLock;
        uint256 timeLock;
        bool completed;
        bool refunded;
        bool isNativeEth; // New: indicates if this escrow uses native ETH
        uint256 createdAt;
        string suiOrderHash;
        bytes32 secret; // Revealed secret stored after completion
    }

    // State variables
    mapping(bytes32 => Escrow) public escrows;
    mapping(bytes32 => bool) public usedSecrets;
    
    // Events
    event EscrowCreated(
        bytes32 indexed escrowId,
        address indexed maker,
        address indexed taker,
        uint256 amount,
        bytes32 hashLock,
        uint256 timeLock,
        bool isNativeEth,
        string suiOrderHash
    );
    
    event EscrowFilled(
        bytes32 indexed escrowId,
        address indexed resolver,
        bytes32 secret,
        uint256 amount,
        bool isNativeEth,
        string suiOrderHash
    );
    
    event EscrowPartiallyFilled(
        bytes32 indexed escrowId,
        address indexed resolver,
        uint256 amount,
        uint256 remainingAmount,
        bytes32 secret,
        bool isNativeEth,
        string suiOrderHash
    );
    
    event EscrowRefunded(
        bytes32 indexed escrowId,
        address indexed maker,
        uint256 amount,
        bool isNativeEth,
        string suiOrderHash
    );
    
    event EscrowCancelled(
        bytes32 indexed escrowId,
        address indexed maker,
        bool isNativeEth,
        string suiOrderHash
    );
    
    // Errors
    error InvalidAmount();
    error InvalidTimeLock();
    error InsufficientWethAllowance();
    error EscrowAlreadyExists();
    error EscrowNotFound();
    error EscrowAlreadyCompleted();
    error EscrowAlreadyRefunded();
    error InvalidSecret();
    error SecretAlreadyUsed();
    error TimeLockNotExpired();
    error NotMaker();
    error NotTaker();
    error InvalidFillAmount();
    error InsufficientRemainingAmount();
    error TransferFailed();
    
    // Constructor
    constructor(address _weth, address initialOwner) Ownable(initialOwner) {
        weth = IERC20(_weth);
    }
    
    /**
     * @dev Creates a new escrow with WETH (ETH must be wrapped first)
     * @param hashLock Hash of the secret (SHA3-256)
     * @param timeLock Unix timestamp when the escrow expires
     * @param taker Address that can claim the escrow
     * @param suiOrderHash Reference to the corresponding Sui order
     * @param wethAmount Amount of WETH to escrow
     * @return escrowId Unique identifier for the escrow
     */
    function createEscrow(
        bytes32 hashLock,
        uint256 timeLock,
        address payable taker,
        string calldata suiOrderHash,
        uint256 wethAmount
    ) external nonReentrant returns (bytes32 escrowId) {
        if (wethAmount == 0) revert InvalidAmount();
        if (timeLock <= block.timestamp) revert InvalidTimeLock();
        
        // Check WETH allowance
        if (weth.allowance(msg.sender, address(this)) < wethAmount) {
            revert InsufficientWethAllowance();
        }
        
        // Generate unique escrow ID
        escrowId = keccak256(
            abi.encodePacked(
                msg.sender,
                taker,
                wethAmount,
                hashLock,
                timeLock,
                block.timestamp,
                block.number,
                false // isNativeEth = false for WETH
            )
        );
        
        if (escrows[escrowId].maker != address(0)) revert EscrowAlreadyExists();
        
        // Transfer WETH to contract
        weth.safeTransferFrom(msg.sender, address(this), wethAmount);
        
        escrows[escrowId] = Escrow({
            maker: payable(msg.sender),
            taker: taker,
            totalAmount: wethAmount,
            remainingAmount: wethAmount,
            hashLock: hashLock,
            timeLock: timeLock,
            completed: false,
            refunded: false,
            isNativeEth: false, // WETH escrow
            createdAt: block.timestamp,
            suiOrderHash: suiOrderHash,
            secret: bytes32(0)
        });

        emit EscrowCreated(
            escrowId,
            msg.sender,
            taker,
            wethAmount,
            hashLock,
            timeLock,
            false, // isNativeEth
            suiOrderHash
        );
    }
    
    /**
     * @dev Creates a new escrow with native ETH
     * @param hashLock Hash of the secret (SHA3-256)
     * @param timeLock Unix timestamp when the escrow expires
     * @param taker Address that can claim the escrow
     * @param suiOrderHash Reference to the corresponding Sui order
     * @return escrowId Unique identifier for the escrow
     */
    function createEscrowWithEth(
        bytes32 hashLock,
        uint256 timeLock,
        address payable taker,
        string calldata suiOrderHash
    ) external payable nonReentrant returns (bytes32 escrowId) {
        if (msg.value == 0) revert InvalidAmount();
        if (timeLock <= block.timestamp) revert InvalidTimeLock();
        
        // Generate unique escrow ID
        escrowId = keccak256(
            abi.encodePacked(
                msg.sender,
                taker,
                msg.value,
                hashLock,
                timeLock,
                block.timestamp,
                block.number,
                true // isNativeEth = true for ETH
            )
        );
        
        if (escrows[escrowId].maker != address(0)) revert EscrowAlreadyExists();
        
        // ETH is already sent with the transaction (msg.value)
        
        escrows[escrowId] = Escrow({
            maker: payable(msg.sender),
            taker: taker,
            totalAmount: msg.value,
            remainingAmount: msg.value,
            hashLock: hashLock,
            timeLock: timeLock,
            completed: false,
            refunded: false,
            isNativeEth: true, // Native ETH escrow
            createdAt: block.timestamp,
            suiOrderHash: suiOrderHash,
            secret: bytes32(0)
        });

        emit EscrowCreated(
            escrowId,
            msg.sender,
            taker,
            msg.value,
            hashLock,
            timeLock,
            true, // isNativeEth
            suiOrderHash
        );
    }
    
    /**
     * @dev Fills an escrow completely with the correct secret
     * @param escrowId The escrow ID to fill
     * @param secret The secret that matches the hash lock
     * @return amount The amount filled
     */
    function fillEscrow(
        bytes32 escrowId,
        bytes32 secret
    ) external nonReentrant returns (uint256 amount) {
        Escrow storage escrow = escrows[escrowId];
        if (escrow.maker == address(0)) revert EscrowNotFound();
        if (escrow.completed) revert EscrowAlreadyCompleted();
        if (escrow.refunded) revert EscrowAlreadyRefunded();
        if (block.timestamp >= escrow.timeLock) revert TimeLockNotExpired();
        
        // Validate caller
        if (escrow.taker != address(0)) {
            if (msg.sender != escrow.taker) revert NotTaker();
        }
        
        // Validate secret
        if (keccak256(abi.encodePacked(secret)) != escrow.hashLock) {
            revert InvalidSecret();
        }
        
        // Check if secret was already used
        if (usedSecrets[secret]) revert SecretAlreadyUsed();
        
        amount = escrow.remainingAmount;
        escrow.remainingAmount = 0;
        escrow.completed = true;
        escrow.secret = secret;
        usedSecrets[secret] = true;
        
        // Transfer funds based on escrow type
        if (escrow.isNativeEth) {
            // Transfer native ETH
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Transfer WETH
            weth.safeTransfer(msg.sender, amount);
        }
        
        emit EscrowFilled(
            escrowId,
            msg.sender,
            secret,
            amount,
            escrow.isNativeEth,
            escrow.suiOrderHash
        );
    }
    
    /**
     * @dev Fills an escrow partially with the correct secret
     * @param escrowId The escrow ID to fill
     * @param secret The secret that matches the hash lock
     * @param fillAmount The amount to fill (must be <= remaining amount)
     * @return filledAmount The amount actually filled
     */
    function fillEscrowPartial(
        bytes32 escrowId,
        bytes32 secret,
        uint256 fillAmount
    ) external nonReentrant returns (uint256 filledAmount) {
        Escrow storage escrow = escrows[escrowId];
        if (escrow.maker == address(0)) revert EscrowNotFound();
        if (escrow.completed) revert EscrowAlreadyCompleted();
        if (escrow.refunded) revert EscrowAlreadyRefunded();
        if (block.timestamp >= escrow.timeLock) revert TimeLockNotExpired();
        if (fillAmount == 0 || fillAmount > escrow.remainingAmount) revert InvalidFillAmount();
        
        // Validate caller
        if (escrow.taker != address(0)) {
            if (msg.sender != escrow.taker) revert NotTaker();
        }
        
        // Validate secret
        if (keccak256(abi.encodePacked(secret)) != escrow.hashLock) {
            revert InvalidSecret();
        }
        
        // Check if secret was already used
        if (usedSecrets[secret]) revert SecretAlreadyUsed();
        
        filledAmount = fillAmount;
        escrow.remainingAmount -= fillAmount;
        escrow.secret = secret;
        usedSecrets[secret] = true;
        
        // Mark as completed if fully filled
        if (escrow.remainingAmount == 0) {
            escrow.completed = true;
        }
        
        // Transfer funds based on escrow type
        if (escrow.isNativeEth) {
            // Transfer native ETH
            (bool success, ) = payable(msg.sender).call{value: filledAmount}("");
            if (!success) revert TransferFailed();
        } else {
            // Transfer WETH
            weth.safeTransfer(msg.sender, filledAmount);
        }
        
        emit EscrowPartiallyFilled(
            escrowId,
            msg.sender,
            filledAmount,
            escrow.remainingAmount,
            secret,
            escrow.isNativeEth,
            escrow.suiOrderHash
        );
    }
    
    /**
     * @dev Refunds an escrow to the maker after time lock expires
     * @param escrowId The escrow ID to refund
     * @return amount The amount refunded
     */
    function refundEscrow(bytes32 escrowId) external nonReentrant returns (uint256 amount) {
        Escrow storage escrow = escrows[escrowId];
        if (escrow.maker == address(0)) revert EscrowNotFound();
        if (escrow.completed) revert EscrowAlreadyCompleted();
        if (escrow.refunded) revert EscrowAlreadyRefunded();
        if (block.timestamp < escrow.timeLock) revert TimeLockNotExpired();
        if (msg.sender != escrow.maker) revert NotMaker();
        
        amount = escrow.remainingAmount;
        escrow.remainingAmount = 0;
        escrow.refunded = true;
        
        // Transfer funds based on escrow type
        if (escrow.isNativeEth) {
            // Transfer native ETH
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Transfer WETH
            weth.safeTransfer(msg.sender, amount);
        }
        
        emit EscrowRefunded(
            escrowId,
            msg.sender,
            amount,
            escrow.isNativeEth,
            escrow.suiOrderHash
        );
    }
    
    /**
     * @dev Cancels an escrow (only maker can cancel before time lock)
     * @param escrowId The escrow ID to cancel
     * @return amount The amount returned
     */
    function cancelEscrow(bytes32 escrowId) external nonReentrant returns (uint256 amount) {
        Escrow storage escrow = escrows[escrowId];
        if (escrow.maker == address(0)) revert EscrowNotFound();
        if (escrow.completed) revert EscrowAlreadyCompleted();
        if (escrow.refunded) revert EscrowAlreadyRefunded();
        if (msg.sender != escrow.maker) revert NotMaker();
        
        amount = escrow.remainingAmount;
        escrow.remainingAmount = 0;
        escrow.refunded = true;
        
        // Transfer funds based on escrow type
        if (escrow.isNativeEth) {
            // Transfer native ETH
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Transfer WETH
            weth.safeTransfer(msg.sender, amount);
        }
        
        emit EscrowCancelled(
            escrowId,
            msg.sender,
            escrow.isNativeEth,
            escrow.suiOrderHash
        );
    }
    
    /**
     * @dev Emergency function to rescue stuck tokens (only owner)
     * @param token The token to rescue
     * @param to The recipient address
     * @param amount The amount to rescue
     */
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // Rescue native ETH
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Rescue ERC20 tokens
            IERC20(token).safeTransfer(to, amount);
        }
    }
    
    /**
     * @dev Get escrow details
     * @param escrowId The escrow ID
     * @return escrow The escrow details
     */
    function getEscrow(bytes32 escrowId) external view returns (Escrow memory escrow) {
        escrow = escrows[escrowId];
    }
    
    /**
     * @dev Check if an escrow exists
     * @param escrowId The escrow ID
     * @return exists True if escrow exists
     */
    function escrowExists(bytes32 escrowId) external view returns (bool exists) {
        return escrows[escrowId].maker != address(0);
    }
    
    /**
     * @dev Check if a secret has been used
     * @param secret The secret to check
     * @return used True if secret has been used
     */
    function isSecretUsed(bytes32 secret) external view returns (bool used) {
        return usedSecrets[secret];
    }
    
    /**
     * @dev Receive function to accept native ETH
     */
    receive() external payable {
        // Allow receiving ETH for escrow creation
    }
} 