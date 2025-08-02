// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MeshLimitOrderProtocol} from "../src/MeshLimitOrderProtocol.sol";
import {IMeshLimitOrderProtocol} from "../src/interfaces/IMeshLimitOrderProtocol.sol";
import {IMeshDutchAuction} from "../src/interfaces/IMeshDutchAuction.sol";
import {IMeshResolverNetwork} from "../src/interfaces/IMeshResolverNetwork.sol";
import {IMeshEscrow} from "../src/interfaces/IMeshEscrow.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MeshLimitOrderProtocolTest is Test {
    MeshLimitOrderProtocol public limitOrderProtocol;
    IERC20 public weth;
    
    address public dutchAuction = address(0x1);
    address public resolverNetwork = address(0x2);
    address public escrowContract = address(0x3);
    address public maker = address(0x4);
    address public resolver = address(0x5);
    
    uint256 public sourceAmount = 10e18; // 10 WETH
    uint256 public destinationAmount = 20e18; // 20 SUI tokens
    uint256 public startTime;
    uint256 public endTime;
    
    event CrossChainOrderCreated(
        bytes32 indexed orderHash,
        address indexed maker,
        uint256 sourceAmount,
        uint256 destinationAmount,
        IMeshLimitOrderProtocol.DutchAuctionConfig auctionConfig
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
    
    function setUp() public {
        // Deploy mock WETH
        weth = IERC20(address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)); // Sepolia WETH
        
        // Deploy limit order protocol
        limitOrderProtocol = new MeshLimitOrderProtocol(
            address(weth),
            dutchAuction,
            resolverNetwork,
            escrowContract
        );
        
        startTime = block.timestamp + 100;
        endTime = startTime + 3600; // 1 hour
        
        // Fund accounts
        vm.deal(maker, 10 ether);
        vm.deal(resolver, 10 ether);
        
        // Mock WETH operations
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.allowance.selector, maker, address(limitOrderProtocol)),
            abi.encode(sourceAmount)
        );
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        
        // Mock dutch auction operations
        vm.mockCall(
            dutchAuction,
            abi.encodeWithSelector(IMeshDutchAuction.initializeAuction.selector),
            abi.encode()
        );
        vm.mockCall(
            dutchAuction,
            abi.encodeWithSelector(IMeshDutchAuction.calculateCurrentRate.selector),
            abi.encode(2e18) // 2 WETH per unit
        );
        
        // Mock resolver network operations
        vm.mockCall(
            resolverNetwork,
            abi.encodeWithSelector(IMeshResolverNetwork.registerOrder.selector),
            abi.encode()
        );
        vm.mockCall(
            resolverNetwork,
            abi.encodeWithSelector(IMeshResolverNetwork.isAuthorized.selector, resolver),
            abi.encode(true)
        );
        vm.mockCall(
            resolverNetwork,
            abi.encodeWithSelector(IMeshResolverNetwork.recordOrderFill.selector),
            abi.encode()
        );
        
        // Mock escrow operations
        vm.mockCall(
            escrowContract,
            abi.encodeWithSelector(IMeshEscrow.createEscrow.selector),
            abi.encode(keccak256("escrow_id"))
        );
        vm.mockCall(
            escrowContract,
            abi.encodeWithSelector(IMeshEscrow.createEscrowWithEth.selector),
            abi.encode(keccak256("escrow_id_eth"))
        );
    }
    
    function testCreateCrossChainOrder() public {
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
        
        // Verify order was created
        IMeshLimitOrderProtocol.LimitOrder memory order = limitOrderProtocol.getOrder(orderHash);
        assertEq(order.maker, maker);
        assertEq(order.taker, address(0)); // Open to any resolver
        assertEq(order.sourceAmount, sourceAmount);
        assertEq(order.destinationAmount, destinationAmount);
        assertTrue(order.isActive);
        assertEq(order.isNativeEth, false); // WETH order
    }

    function testCreateCrossChainOrderWithEth() public {
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrderWithEth{value: sourceAmount}(
            destinationAmount,
            auctionConfig
        );
        
        // Verify order was created
        IMeshLimitOrderProtocol.LimitOrder memory order = limitOrderProtocol.getOrder(orderHash);
        assertEq(order.maker, maker);
        assertEq(order.taker, address(0)); // Open to any resolver
        assertEq(order.sourceAmount, sourceAmount);
        assertEq(order.destinationAmount, destinationAmount);
        assertTrue(order.isActive);
        assertEq(order.isNativeEth, true); // Native ETH order
        assertEq(order.auctionConfig.auctionStartTime, startTime);
        assertEq(order.auctionConfig.auctionEndTime, endTime);
    }
    
    function testCreateCrossChainOrderInvalidSourceAmount() public {
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshLimitOrderProtocol.InvalidSourceAmount.selector);
        limitOrderProtocol.createCrossChainOrder(
            100, // Too small (< 0.001 WETH)
            destinationAmount,
            auctionConfig
        );
    }
    
    function testCreateCrossChainOrderInvalidDestinationAmount() public {
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshLimitOrderProtocol.InvalidDestinationAmount.selector);
        limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            0, // Invalid destination amount
            auctionConfig
        );
    }
    
    function testCreateCrossChainOrderInvalidAuctionTimes() public {
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: endTime, // Start after end
            auctionEndTime: startTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshLimitOrderProtocol.InvalidAuctionTimes.selector);
        limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
    }
    
    function testCreateCrossChainOrderAuctionTooShort() public {
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: startTime + 100, // Only 100 seconds
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshLimitOrderProtocol.AuctionTooShort.selector);
        limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
    }
    
    function testCreateCrossChainOrderInsufficientAllowance() public {
        // Mock insufficient allowance
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.allowance.selector, maker, address(limitOrderProtocol)),
            abi.encode(sourceAmount - 1)
        );
        
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshLimitOrderProtocol.InsufficientAllowance.selector);
        limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
    }
    
    function testFillLimitOrder() public {
        // Create order first
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
        
        // Move to auction time
        vm.warp(startTime + 100);
        
        bytes32 secret = keccak256("test_secret");
        uint256 fillAmount = 5e18;
        
        vm.prank(resolver);
        uint256 filledAmount = limitOrderProtocol.fillLimitOrder(
            orderHash,
            secret,
            fillAmount
        );
        
        assertEq(filledAmount, fillAmount);
        
        // Verify order state was updated
        IMeshLimitOrderProtocol.LimitOrder memory order = limitOrderProtocol.getOrder(orderHash);
        assertEq(order.taker, resolver);
    }
    
    function testFillLimitOrderNotFound() public {
        bytes32 nonExistentOrderHash = keccak256("non_existent");
        
        vm.prank(resolver);
        vm.expectRevert(IMeshLimitOrderProtocol.OrderNotFound.selector);
        limitOrderProtocol.fillLimitOrder(
            nonExistentOrderHash,
            keccak256("test_secret"),
            5e18
        );
    }
    
    function testFillLimitOrderUnauthorizedResolver() public {
        // Create order first
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
        
        // Mock unauthorized resolver
        vm.mockCall(
            resolverNetwork,
            abi.encodeWithSelector(IMeshResolverNetwork.isAuthorized.selector, resolver),
            abi.encode(false)
        );
        
        vm.warp(startTime + 100);
        
        vm.prank(resolver);
        vm.expectRevert(IMeshLimitOrderProtocol.UnauthorizedResolver.selector);
        limitOrderProtocol.fillLimitOrder(
            orderHash,
            keccak256("test_secret"),
            5e18
        );
    }
    
    function testCancelOrder() public {
        // Create order first
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
        
        vm.prank(maker);
        vm.expectEmit(true, true, false, false);
        emit OrderCancelled(orderHash, maker);
        
        limitOrderProtocol.cancelOrder(orderHash);
        
        // Verify order is cancelled
        assertFalse(limitOrderProtocol.isOrderActive(orderHash));
        assertTrue(limitOrderProtocol.cancelledOrders(orderHash));
    }
    
    function testCancelOrderNotFound() public {
        bytes32 nonExistentOrderHash = keccak256("non_existent");
        
        vm.prank(maker);
        vm.expectRevert(IMeshLimitOrderProtocol.OrderNotFound.selector);
        limitOrderProtocol.cancelOrder(nonExistentOrderHash);
    }
    
    function testCancelOrderNotMaker() public {
        // Create order first
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
        
        vm.prank(resolver); // Not the maker
        vm.expectRevert(IMeshLimitOrderProtocol.NotMaker.selector);
        limitOrderProtocol.cancelOrder(orderHash);
    }
    
    function testIsOrderActive() public {
        // Create order first
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
        
        // Should be active initially
        assertTrue(limitOrderProtocol.isOrderActive(orderHash));
        
        // Should be inactive after cancellation
        vm.prank(maker);
        limitOrderProtocol.cancelOrder(orderHash);
        assertFalse(limitOrderProtocol.isOrderActive(orderHash));
    }
    
    function testGetCurrentRate() public {
        // Create order first
        IMeshLimitOrderProtocol.DutchAuctionConfig memory auctionConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        vm.prank(maker);
        bytes32 orderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
        
        uint256 currentRate = limitOrderProtocol.getCurrentRate(orderHash);
        assertEq(currentRate, 2e18); // Mocked rate
    }
    
    function testGetCurrentRateOrderNotFound() public {
        bytes32 nonExistentOrderHash = keccak256("non_existent");
        
        vm.expectRevert(IMeshLimitOrderProtocol.OrderNotFound.selector);
        limitOrderProtocol.getCurrentRate(nonExistentOrderHash);
    }
    
    function testContractDependencies() public {
        assertEq(address(limitOrderProtocol.weth()), address(weth));
        assertEq(address(limitOrderProtocol.dutchAuction()), dutchAuction);
        assertEq(address(limitOrderProtocol.resolverNetwork()), resolverNetwork);
        assertEq(address(limitOrderProtocol.escrowContract()), escrowContract);
    }
    
    function testConstants() public {
        assertEq(limitOrderProtocol.MIN_AUCTION_DURATION(), 300);
        assertEq(limitOrderProtocol.MAX_AUCTION_DURATION(), 86400);
        assertEq(limitOrderProtocol.MIN_ORDER_AMOUNT(), 1e15);
    }
}