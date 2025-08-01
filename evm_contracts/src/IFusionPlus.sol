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

    // ===== Dutch Auction Structs =====

    struct RateCurvePoint {
        uint256 timeDelta;    // Time from auction start
        uint256 rateBump;     // Rate advantage at this time
    }

    struct AuctionDetails {
        uint256 initialRateBump;      // Starting rate advantage (basis points)
        uint256 duration;             // Auction duration in seconds
        uint256 startTime;            // Auction start timestamp
        bool isActive;                // Auction status
        RateCurvePoint[] rateCurvePoints; // Rate degradation curve
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

    event DutchAuctionStarted(
        bytes32 indexed orderHash,
        uint256 startTime,
        uint256 duration,
        uint256 initialRateBump
    );

    event DutchAuctionFilled(
        bytes32 indexed orderHash,
        address indexed resolver,
        uint256 fillRate,
        uint256 fillAmount
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

    // ===== Dutch Auction Functions =====

    function startAuction(
        bytes32 orderHash,
        AuctionDetails memory auctionDetails
    ) external;

    function getCurrentRate(bytes32 orderHash) external view returns (uint256);

    function fillOrder(
        bytes32 orderHash,
        uint256 fillAmount,
        bytes32 secret
    ) external payable returns (uint256);

    function isAuctionActive(bytes32 orderHash) external view returns (bool);
} 