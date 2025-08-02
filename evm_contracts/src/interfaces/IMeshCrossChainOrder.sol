// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMeshCrossChainOrder
 * @dev Interface for Mesh CrossChainOrder (1inch Fusion+)
 */
interface IMeshCrossChainOrder {
    // Structs
    struct CrossChainOrder {
        address maker;
        uint256 sourceAmount;
        uint256 destinationAmount;
        DutchAuctionConfig auctionConfig;
        CrossChainConfig crossChainConfig;
        bytes32 orderHash;
        bool isActive;
        bool isNativeEth; // New: indicates if this order uses native ETH
        uint256 createdAt;
        uint256 totalFills;
        uint256 remainingAmount;
    }

    struct DutchAuctionConfig {
        uint256 auctionStartTime;
        uint256 auctionEndTime;
        uint256 startRate;
        uint256 endRate;
    }

    struct CrossChainConfig {
        string suiOrderHash;
        uint256 timelockDuration;
        string destinationAddress;
        bytes32 secretHash;
    }

    // Events
    event CrossChainOrderCreated(
        bytes32 indexed orderHash,
        bytes32 indexed limitOrderHash,
        address indexed maker,
        uint256 sourceAmount,
        uint256 destinationAmount,
        DutchAuctionConfig auctionConfig,
        CrossChainConfig crossChainConfig
    );

    event CrossChainOrderFilled(
        bytes32 indexed orderHash,
        address indexed resolver,
        bytes32 secret,
        uint256 fillAmount,
        bytes32 escrowId,
        string suiTransactionHash
    );

    event CrossChainOrderCancelled(
        bytes32 indexed orderHash,
        address indexed maker
    );

    // Errors
    error InvalidSourceAmount();
    error ExcessiveSourceAmount();
    error InvalidDestinationAmount();
    error InvalidTimelockDuration();
    error InsufficientAllowance();
    error OrderAlreadyExists();
    error OrderNotFound();
    error OrderNotActive();
    error OrderCancelled();
    error OrderExpired();
    error InsufficientRemainingAmount();
    error InvalidSecret();
    error TransferFailed();
    error NotMaker();

    // Functions
    function createCrossChainOrder(
        uint256 sourceAmount,
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig,
        CrossChainConfig calldata crossChainConfig
    ) external returns (bytes32 orderHash);

    function createCrossChainOrderWithEth(
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig,
        CrossChainConfig calldata crossChainConfig
    ) external payable returns (bytes32 orderHash);

    function fillCrossChainOrder(
        bytes32 orderHash,
        bytes32 secret,
        uint256 fillAmount,
        string calldata suiTransactionHash
    ) external returns (uint256 filledAmount);

    function cancelCrossChainOrder(bytes32 orderHash) external;

    function getCrossChainOrder(bytes32 orderHash) external view returns (CrossChainOrder memory order);

    function isCrossChainOrderActive(bytes32 orderHash) external view returns (bool active);

    function getOrderStats(bytes32 orderHash) external view returns (
        uint256 totalFills,
        uint256 remainingAmount,
        uint256 timeRemaining
    );

    function validateCrossChainConfig(CrossChainConfig calldata config) external pure returns (bool valid);
} 