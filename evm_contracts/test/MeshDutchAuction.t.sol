// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MeshDutchAuction} from "../src/core/MeshDutchAuction.sol";
import {IMeshDutchAuction} from "../src/interfaces/IMeshDutchAuction.sol";

contract MeshDutchAuctionTest is Test {
    MeshDutchAuction public dutchAuction;
    
    address public limitOrderProtocol = address(0x1);
    address public user = address(0x2);
    
    bytes32 public orderHash = keccak256("test_order");
    uint256 public startTime;
    uint256 public endTime;
    uint256 public startRate = 1000e18; // 1000 WETH per unit
    uint256 public endRate = 500e18;    // 500 WETH per unit
    uint256 public decreaseRate = 10e18; // 10 WETH per second
    
    event AuctionInitialized(
        bytes32 indexed orderHash,
        IMeshDutchAuction.DutchAuctionConfig config
    );
    
    event AuctionCancelled(
        bytes32 indexed orderHash
    );
    
    event BidRecorded(
        bytes32 indexed orderHash,
        address indexed bidder,
        uint256 bidAmount,
        uint256 timestamp
    );
    
    function setUp() public {
        dutchAuction = new MeshDutchAuction(limitOrderProtocol);
        
        startTime = block.timestamp + 100;
        endTime = startTime + 3600; // 1 hour auction
        
        // Fund accounts
        vm.deal(user, 10 ether);
    }
    
    function testInitializeAuction() public {
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        vm.expectEmit(true, false, false, true);
        emit AuctionInitialized(orderHash, config);
        
        dutchAuction.initializeAuction(orderHash, config);
        
        // Verify auction was created
        IMeshDutchAuction.Auction memory auction = dutchAuction.getAuction(orderHash);
        assertEq(auction.orderHash, orderHash);
        assertEq(auction.config.auctionStartTime, startTime);
        assertEq(auction.config.auctionEndTime, endTime);
        assertEq(auction.config.startRate, startRate);
        assertEq(auction.config.endRate, endRate);
        assertEq(auction.isActive, true);
    }
    
    function testInitializeAuctionOnlyLimitOrderProtocol() public {
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(user);
        vm.expectRevert(IMeshDutchAuction.OnlyLimitOrderProtocol.selector);
        dutchAuction.initializeAuction(orderHash, config);
    }
    
    function testInitializeAuctionInvalidTimes() public {
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: endTime, // Start after end
            auctionEndTime: startTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshDutchAuction.InvalidAuctionTimes.selector);
        dutchAuction.initializeAuction(orderHash, config);
    }
    
    function testInitializeAuctionTooShort() public {
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: startTime + 100, // Only 100 seconds (< 300 min)
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshDutchAuction.AuctionTooShort.selector);
        dutchAuction.initializeAuction(orderHash, config);
    }
    
    function testInitializeAuctionTooLong() public {
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: startTime + 100000, // > 24 hours
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshDutchAuction.AuctionTooLong.selector);
        dutchAuction.initializeAuction(orderHash, config);
    }
    
    function testCalculateCurrentRate() public {
        // Initialize auction first
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        dutchAuction.initializeAuction(orderHash, config);
        
        // Test rate at start time
        vm.warp(startTime);
        uint256 currentRate = dutchAuction.calculateCurrentRate(orderHash);
        assertEq(currentRate, startRate);
        
        // Test rate at middle of auction
        vm.warp(startTime + 1800); // 30 minutes in
        currentRate = dutchAuction.calculateCurrentRate(orderHash);
        assertTrue(currentRate < startRate);
        assertTrue(currentRate > endRate);
        
        // Test rate at end time
        vm.warp(endTime);
        currentRate = dutchAuction.calculateCurrentRate(orderHash);
        assertEq(currentRate, endRate);
    }
    
    function testCancelAuction() public {
        // Initialize auction first
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        dutchAuction.initializeAuction(orderHash, config);
        
        // Cancel auction
        vm.prank(limitOrderProtocol);
        vm.expectEmit(true, false, false, false);
        emit AuctionCancelled(orderHash);
        
        dutchAuction.cancelAuction(orderHash);
        
        // Verify auction is cancelled
        assertFalse(dutchAuction.isAuctionActive(orderHash));
    }
    
    function testCancelAuctionOnlyLimitOrderProtocol() public {
        // Initialize auction first
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        dutchAuction.initializeAuction(orderHash, config);
        
        // Try to cancel from non-authorized address
        vm.prank(user);
        vm.expectRevert(IMeshDutchAuction.OnlyLimitOrderProtocol.selector);
        dutchAuction.cancelAuction(orderHash);
    }
    
    function testRecordBid() public {
        // Initialize auction first
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        dutchAuction.initializeAuction(orderHash, config);
        
        // Move to auction start time
        vm.warp(startTime + 100);
        
        uint256 bidAmount = 800e18;
        
        vm.prank(limitOrderProtocol);
        vm.expectEmit(true, true, false, true);
        emit BidRecorded(orderHash, user, bidAmount, block.timestamp);
        
        dutchAuction.recordBid(orderHash, user, bidAmount);
        
        // Verify bid was recorded
        (uint256 totalBids, uint256 highestBid, address highestBidder, uint256 lastBidTimestamp) = 
            dutchAuction.getAuctionStats(orderHash);
        
        assertEq(totalBids, 1);
        assertEq(highestBid, bidAmount);
        assertEq(highestBidder, user);
        assertEq(lastBidTimestamp, block.timestamp);
    }
    
    function testRecordBidOnlyLimitOrderProtocol() public {
        // Initialize auction first
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        dutchAuction.initializeAuction(orderHash, config);
        
        vm.warp(startTime + 100);
        
        vm.prank(user);
        vm.expectRevert(IMeshDutchAuction.OnlyLimitOrderProtocol.selector);
        dutchAuction.recordBid(orderHash, user, 800e18);
    }
    
    function testIsAuctionActive() public {
        // Initialize auction first
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        dutchAuction.initializeAuction(orderHash, config);
        
        // Before start time
        vm.warp(startTime - 100);
        assertFalse(dutchAuction.isAuctionActive(orderHash));
        
        // During auction
        vm.warp(startTime + 100);
        assertTrue(dutchAuction.isAuctionActive(orderHash));
        
        // After end time
        vm.warp(endTime + 100);
        assertFalse(dutchAuction.isAuctionActive(orderHash));
        
        // After cancellation
        vm.warp(startTime + 100);
        vm.prank(limitOrderProtocol);
        dutchAuction.cancelAuction(orderHash);
        assertFalse(dutchAuction.isAuctionActive(orderHash));
    }
    
    function testAuctionAlreadyExists() public {
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: startRate,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        dutchAuction.initializeAuction(orderHash, config);
        
        // Try to initialize same auction again
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshDutchAuction.AuctionAlreadyExists.selector);
        dutchAuction.initializeAuction(orderHash, config);
    }
    
    function testInvalidRates() public {
        // Start rate = 0
        IMeshDutchAuction.DutchAuctionConfig memory config = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 0,
            endRate: endRate,
            decreaseRate: decreaseRate
        });
        
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshDutchAuction.InvalidRates.selector);
        dutchAuction.initializeAuction(orderHash, config);
        
        // End rate = 0
        config.startRate = startRate;
        config.endRate = 0;
        
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshDutchAuction.InvalidRates.selector);
        dutchAuction.initializeAuction(orderHash, config);
        
        // Start rate <= end rate
        config.startRate = 500e18;
        config.endRate = 1000e18;
        
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshDutchAuction.InvalidRateProgression.selector);
        dutchAuction.initializeAuction(orderHash, config);
    }
}