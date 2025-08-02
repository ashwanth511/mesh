// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMeshLimitOrderProtocol
 * @dev Interface for Mesh Limit Order Protocol (1inch Fusion+)
 */
interface IMeshLimitOrderProtocol {
    // Structs
    struct LimitOrder {
        address maker;
        address taker;
        uint256 sourceAmount;
        uint256 destinationAmount;
        uint256 deadline;
        bytes32 orderHash;
        bool isActive;
        bool isNativeEth; // New: indicates if this order uses native ETH
        uint256 createdAt;
        DutchAuctionConfig auctionConfig;
    }

    struct DutchAuctionConfig {
        uint256 auctionStartTime;
        uint256 auctionEndTime;
        uint256 startRate;
        uint256 endRate;
    }

    // Events
    event CrossChainOrderCreated(
        bytes32 indexed orderHash,
        address indexed maker,
        uint256 sourceAmount,
        uint256 destinationAmount,
        DutchAuctionConfig auctionConfig
    );

    event LimitOrderFilled(
        bytes32 indexed orderHash,
        address indexed resolver,
        bytes32 secret,
        uint256 fillAmount,
        uint256 takingAmount,
        uint256 rate
    );

    event OrderCancelled(
        bytes32 indexed orderHash,
        address indexed maker
    );

    // Errors
    error InvalidSourceAmount();
    error InvalidDestinationAmount();
    error InvalidAuctionTimes();
    error AuctionTooShort();
    error AuctionTooLong();
    error InvalidRates();
    error InsufficientAllowance();
    error OrderAlreadyExists();
    error OrderNotFound();
    error OrderNotActive();
    error OrderAlreadyCancelled();
    error OrderExpired();
    error UnauthorizedResolver();
    error InvalidRate();
    error InsufficientDestinationAmount();
    error TransferFailed();
    error NotMaker();

    // Functions
    function createCrossChainOrder(
        uint256 sourceAmount,
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig
    ) external returns (bytes32 orderHash);

    function createCrossChainOrderWithEth(
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig
    ) external payable returns (bytes32 orderHash);

    function fillLimitOrder(
        bytes32 orderHash,
        bytes32 secret,
        uint256 fillAmount
    ) external returns (uint256 filledAmount);

    function cancelOrder(bytes32 orderHash) external;

    function getOrder(bytes32 orderHash) external view returns (LimitOrder memory order);

    function isOrderActive(bytes32 orderHash) external view returns (bool active);

    function getCurrentRate(bytes32 orderHash) external view returns (uint256 rate);
} 