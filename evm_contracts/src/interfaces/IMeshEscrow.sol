// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMeshEscrow
 * @dev Interface for Mesh Escrow (HTLC)
 */
interface IMeshEscrow {
    // Structs
    struct Escrow {
        address payable maker;
        address payable taker;
        uint256 totalAmount;
        uint256 remainingAmount;
        bytes32 hashLock;
        uint256 timeLock;
        bool completed;
        bool refunded;
        bool isNativeEth; // New: indicates if this escrow uses native ETH
        uint256 createdAt;
        string suiOrderHash;
        bytes32 secret;
    }

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

    // Functions
    function createEscrow(
        bytes32 hashLock,
        uint256 timeLock,
        address payable taker,
        string calldata suiOrderHash,
        uint256 wethAmount
    ) external returns (bytes32 escrowId);

    function createEscrowWithEth(
        bytes32 hashLock,
        uint256 timeLock,
        address payable taker,
        string calldata suiOrderHash
    ) external payable returns (bytes32 escrowId);

    function fillEscrow(
        bytes32 escrowId,
        bytes32 secret
    ) external returns (uint256 amount);

    function fillEscrowPartial(
        bytes32 escrowId,
        uint256 amount,
        bytes32 secret
    ) external returns (uint256 filledAmount);

    function refundEscrow(bytes32 escrowId) external returns (uint256 amount);

    function cancelEscrow(bytes32 escrowId) external returns (uint256 amount);

    function getEscrow(bytes32 escrowId) external view returns (Escrow memory escrow);

    function escrowExists(bytes32 escrowId) external view returns (bool exists);

    function isSecretUsed(bytes32 secret) external view returns (bool used);
} 