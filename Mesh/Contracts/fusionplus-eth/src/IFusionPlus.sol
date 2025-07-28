// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @title IFusionPlus - Shared interface for Fusion+ contracts
 * @notice Defines shared structs and interfaces for cross-chain swaps
 * @custom:security-contact security@1inch.io
 */
interface IFusionPlus {
    // ===== Shared Structs =====

    struct Timelocks {
        uint256 srcWithdrawal;
        uint256 srcPublicWithdrawal;
        uint256 srcCancellation;
        uint256 srcPublicCancellation;
        uint256 dstWithdrawal;
        uint256 dstPublicWithdrawal;
        uint256 dstCancellation;
    }

    struct Immutables {
        address maker;
        address taker;
        address token;
        uint256 amount;
        bytes32 hashlock;
        Timelocks timelocks;
        uint256 safetyDeposit;
        uint256 deployedAt;
    }

    struct OrderConfig {
        uint32 id;
        uint256 srcAmount;
        uint256 minDstAmount;
        uint256 estimatedDstAmount;
        uint256 expirationTime;
        bool srcAssetIsNative;
        bool dstAssetIsNative;
        FeeConfig fee;
        uint256 cancellationAuctionDuration;
    }

    struct FeeConfig {
        uint16 protocolFee;
        uint16 integratorFee;
        uint8 surplusPercentage;
        uint256 maxCancellationPremium;
    }

    struct EscrowStatus {
        bool isFilled;
        bool isCancelled;
        uint256 deployedAt;
        uint256 filledAt;
        uint256 cancelledAt;
    }

    // ===== Events =====

    event EscrowCreated(
        bytes32 indexed orderHash,
        address indexed creator,
        bool isSource
    );

    event EscrowWithdrawn(
        bytes32 indexed orderHash,
        address indexed recipient,
        uint256 amount
    );

    event EscrowCancelled(
        bytes32 indexed orderHash,
        address indexed canceller,
        uint256 amount
    );

    // ===== Functions =====

    function createEscrowSrc(
        bytes32 orderHash,
        Immutables memory immutables
    ) external payable;

    function createEscrowDst(
        bytes32 orderHash,
        Immutables memory immutables
    ) external payable;

    function withdraw(
        bytes32 orderHash,
        bytes32 secret
    ) external returns (uint256);

    function cancel(
        bytes32 orderHash
    ) external returns (uint256);


} 