// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMeshDutchAuction
 * @dev Interface for Mesh Dutch Auction (1inch Fusion+)
 */
interface IMeshDutchAuction {
    // Structs
    struct DutchAuctionConfig {
        uint256 auctionStartTime;
        uint256 auctionEndTime;
        uint256 startRate;
        uint256 endRate;
        uint256 decreaseRate;
    }

    struct Auction {
        bytes32 orderHash;
        DutchAuctionConfig config;
        bool isActive;
        uint256 currentRate;
    }

    // Events
    event AuctionInitialized(
        bytes32 indexed orderHash,
        DutchAuctionConfig config
    );

    event AuctionCompleted(
        bytes32 indexed orderHash,
        uint256 finalRate
    );

    event AuctionCancelled(
        bytes32 indexed orderHash
    );

    // Errors
    error OnlyLimitOrderProtocol();
    error AuctionAlreadyExists();
    error AuctionNotFound();
    error AuctionNotActive();
    error InvalidAuctionConfig();
    error AuctionNotStarted();
    error AuctionEnded();
    error InvalidAuctionTimes();
    error InvalidRates();
    error InvalidRateProgression();
    error AuctionTooShort();
    error AuctionTooLong();

    // Functions
    function initializeAuction(
        bytes32 orderHash,
        DutchAuctionConfig calldata config
    ) external;

    function calculateCurrentRate(bytes32 orderHash) external view returns (uint256 rate);

    function getAuction(bytes32 orderHash) external view returns (Auction memory auction);

    function isAuctionActive(bytes32 orderHash) external view returns (bool active);
} 