// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMeshDutchAuction} from "../interfaces/IMeshDutchAuction.sol";
import {IMeshLimitOrderProtocol} from "../interfaces/IMeshLimitOrderProtocol.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";

/**
 * @title MeshDutchAuction
 * @dev Enhanced Dutch auction implementation for Mesh 1inch Fusion+ Limit Orders
 * Provides competitive price discovery through decreasing rate mechanism with improvements
 */
contract MeshDutchAuction is ReentrancyGuard, IMeshDutchAuction {
    // State variables
    mapping(bytes32 => AuctionData) public auctions;
    mapping(bytes32 => bool) public cancelledAuctions;
    mapping(bytes32 => uint256) public lastBidTime;
    mapping(bytes32 => address) public lastBidder;

    // Only the LimitOrderProtocol can initialize auctions
    address public limitOrderProtocol;

    // Enhanced features
    uint256 public constant MIN_AUCTION_DURATION = 300; // 5 minutes
    uint256 public constant MAX_AUCTION_DURATION = 86400; // 24 hours
    uint256 public constant BID_EXTENSION_WINDOW = 300; // 5 minutes
    uint256 public constant MIN_BID_INCREASE = 1e15; // 0.001 WETH

    constructor(address _limitOrderProtocol) {
        limitOrderProtocol = _limitOrderProtocol;
    }
    
    /**
     * @dev Updates the LimitOrderProtocol address (only callable by current limitOrderProtocol)
     */
    function setLimitOrderProtocol(address _newLimitOrderProtocol) external {
        require(msg.sender == limitOrderProtocol || limitOrderProtocol == address(0), "Only current LOP can update");
        limitOrderProtocol = _newLimitOrderProtocol;
    }

    modifier onlyLimitOrderProtocol() {
        if (msg.sender != limitOrderProtocol) revert OnlyLimitOrderProtocol();
        _;
    }

    /**
     * @dev Initializes a Dutch auction for an order with enhanced features
     */
    function initializeAuction(
        bytes32 orderHash,
        DutchAuctionConfig calldata config
    ) external onlyLimitOrderProtocol {
        if (auctions[orderHash].startTime != 0) revert AuctionAlreadyExists();
        if (config.auctionStartTime >= config.auctionEndTime) revert InvalidAuctionTimes();
        if (config.startRate == 0 || config.endRate == 0) revert InvalidRates();
        if (config.startRate <= config.endRate) revert InvalidRateProgression();
        
        // Enhanced validation
        uint256 duration = config.auctionEndTime - config.auctionStartTime;
        if (duration < MIN_AUCTION_DURATION) revert AuctionTooShort();
        if (duration > MAX_AUCTION_DURATION) revert AuctionTooLong();

        // Calculate decrease rate if not provided
        uint256 decreaseRate = config.decreaseRate;
        if (decreaseRate == 0) {
            decreaseRate = (config.startRate - config.endRate) / duration;
        }

        auctions[orderHash] = AuctionData({
            orderHash: orderHash,
            startTime: config.auctionStartTime,
            endTime: config.auctionEndTime,
            startRate: config.startRate,
            endRate: config.endRate,
            decreaseRate: decreaseRate,
            isActive: true,
            totalBids: 0,
            highestBid: 0,
            highestBidder: address(0)
        });

        emit AuctionInitialized(
            orderHash,
            config
        );
    }

    /**
     * @dev Cancels an active auction
     */
    function cancelAuction(bytes32 orderHash) external onlyLimitOrderProtocol {
        AuctionData storage auction = auctions[orderHash];
        
        if (auction.startTime == 0) revert AuctionNotFound();
        if (!auction.isActive) revert AuctionNotActive();
        if (cancelledAuctions[orderHash]) revert AuctionAlreadyCancelled();

        auction.isActive = false;
        cancelledAuctions[orderHash] = true;

        emit AuctionCancelled(orderHash);
    }

    /**
     * @dev Calculates the current rate for a Dutch auction with enhanced logic
     */
    function calculateCurrentRate(bytes32 orderHash) external view returns (uint256) {
        AuctionData memory auction = auctions[orderHash];
        
        if (auction.startTime == 0) return 0;
        if (!auction.isActive) return 0;
        if (cancelledAuctions[orderHash]) return 0;
        if (block.timestamp < auction.startTime) return auction.startRate;
        if (block.timestamp >= auction.endTime) return auction.endRate;

        // Enhanced linear decrease with bid influence
        uint256 timeElapsed = block.timestamp - auction.startTime;
        uint256 totalDuration = auction.endTime - auction.startTime;
        
        uint256 baseRate;
        if (timeElapsed >= totalDuration) {
            baseRate = auction.endRate;
        } else {
            // Linear interpolation
            uint256 rateDecrease = (auction.startRate - auction.endRate) * timeElapsed / totalDuration;
            baseRate = auction.startRate - rateDecrease;
        }

        // Apply bid influence if there are recent bids
        if (auction.highestBid > 0 && block.timestamp - lastBidTime[orderHash] < BID_EXTENSION_WINDOW) {
            // Boost rate based on recent bid activity
            uint256 bidInfluence = (auction.highestBid * 1e18) / auction.startRate;
            baseRate = baseRate + (bidInfluence / 100); // 1% influence per bid
        }

        return baseRate;
    }

    /**
     * @dev Records a bid for an auction (enhanced feature)
     */
    function recordBid(bytes32 orderHash, address bidder, uint256 bidAmount) external onlyLimitOrderProtocol {
        AuctionData storage auction = auctions[orderHash];
        
        if (auction.startTime == 0) revert AuctionNotFound();
        if (!auction.isActive) revert AuctionNotActive();
        if (block.timestamp < auction.startTime || block.timestamp >= auction.endTime) revert AuctionNotActive();

        // Update bid information
        if (bidAmount > auction.highestBid) {
            auction.highestBid = bidAmount;
            auction.highestBidder = bidder;
        }
        
        auction.totalBids++;
        lastBidTime[orderHash] = block.timestamp;
        lastBidder[orderHash] = bidder;

        emit BidRecorded(orderHash, bidder, bidAmount, block.timestamp);
    }

    /**
     * @dev Gets auction details
     */
    function getAuction(bytes32 orderHash) external view returns (Auction memory auction) {
        AuctionData memory data = auctions[orderHash];
        auction = Auction({
            orderHash: data.orderHash,
            config: DutchAuctionConfig({
                auctionStartTime: data.startTime,
                auctionEndTime: data.endTime,
                startRate: data.startRate,
                endRate: data.endRate,
                decreaseRate: data.decreaseRate
            }),
            isActive: data.isActive,
            currentRate: this.calculateCurrentRate(orderHash)
        });
    }

    /**
     * @dev Checks if auction is active
     */
    function isAuctionActive(bytes32 orderHash) external view returns (bool active) {
        AuctionData memory auction = auctions[orderHash];
        active = auction.isActive && 
                 !cancelledAuctions[orderHash] && 
                 block.timestamp >= auction.startTime && 
                 block.timestamp < auction.endTime;
    }

    /**
     * @dev Gets auction statistics
     */
    function getAuctionStats(bytes32 orderHash) external view returns (
        uint256 totalBids,
        uint256 highestBid,
        address highestBidder,
        uint256 lastBidTimestamp
    ) {
        AuctionData memory auction = auctions[orderHash];
        totalBids = auction.totalBids;
        highestBid = auction.highestBid;
        highestBidder = auction.highestBidder;
        lastBidTimestamp = lastBidTime[orderHash];
    }

    // Enhanced events
    event BidRecorded(
        bytes32 indexed orderHash,
        address indexed bidder,
        uint256 bidAmount,
        uint256 timestamp
    );

    // Enhanced errors
    error AuctionAlreadyCancelled();

    // Enhanced structs
    struct AuctionData {
        bytes32 orderHash;
        uint256 startTime;
        uint256 endTime;
        uint256 startRate;
        uint256 endRate;
        uint256 decreaseRate;
        bool isActive;
        uint256 totalBids;
        uint256 highestBid;
        address highestBidder;
    }
} 