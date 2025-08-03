// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MeshCrossChainOrder} from "../src/core/MeshCrossChainOrder.sol";
import {IMeshCrossChainOrder} from "../src/interfaces/IMeshCrossChainOrder.sol";
import {IMeshLimitOrderProtocol} from "../src/interfaces/IMeshLimitOrderProtocol.sol";
import {IMeshEscrow} from "../src/interfaces/IMeshEscrow.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MeshCrossChainOrderTest is Test {
    MeshCrossChainOrder public crossChainOrder;
    IERC20 public weth;
    
    address public limitOrderProtocol = address(0x1);
    address public escrowContract = address(0x2);
    address public maker = address(0x3);
    address public resolver = address(0x4);
    
    uint256 public sourceAmount = 10e18; // 10 WETH
    uint256 public destinationAmount = 20e18; // 20 SUI tokens
    uint256 public startTime;
    uint256 public endTime;
    
    event CrossChainOrderCreated(
        bytes32 indexed orderHash,
        bytes32 indexed limitOrderHash,
        address indexed maker,
        uint256 sourceAmount,
        uint256 destinationAmount,
        IMeshCrossChainOrder.DutchAuctionConfig auctionConfig,
        IMeshCrossChainOrder.CrossChainConfig crossChainConfig
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
    
    function setUp() public {
        // Deploy mock WETH
        weth = IERC20(address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)); // Sepolia WETH
        
        // Deploy cross-chain order contract
        crossChainOrder = new MeshCrossChainOrder(
            address(weth),
            limitOrderProtocol,
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
            abi.encodeWithSelector(IERC20.allowance.selector, maker, address(crossChainOrder)),
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
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );
        
        // Mock limit order protocol operations
        vm.mockCall(
            limitOrderProtocol,
            abi.encodeWithSelector(IMeshLimitOrderProtocol.createCrossChainOrder.selector),
            abi.encode(keccak256("limit_order_hash"))
        );
        vm.mockCall(
            limitOrderProtocol,
            abi.encodeWithSelector(IMeshLimitOrderProtocol.createCrossChainOrderWithEth.selector),
            abi.encode(keccak256("limit_order_hash_eth"))
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
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600, // 1 hour
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        bytes32 orderHash = crossChainOrder.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
        
        // Verify order was created
        IMeshCrossChainOrder.CrossChainOrder memory order = crossChainOrder.getCrossChainOrder(orderHash);
        assertEq(order.maker, maker);
        assertEq(order.sourceAmount, sourceAmount);
        assertEq(order.destinationAmount, destinationAmount);
        assertTrue(order.isActive);
        assertEq(order.remainingAmount, sourceAmount);
        assertEq(order.isNativeEth, false); // WETH order
    }

    function testCreateCrossChainOrderWithEth() public {
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_eth_123",
            timelockDuration: 3600, // 1 hour
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        bytes32 orderHash = crossChainOrder.createCrossChainOrderWithEth{value: sourceAmount}(
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
        
        // Verify order was created
        IMeshCrossChainOrder.CrossChainOrder memory order = crossChainOrder.getCrossChainOrder(orderHash);
        assertEq(order.maker, maker);
        assertEq(order.sourceAmount, sourceAmount);
        assertEq(order.destinationAmount, destinationAmount);
        assertTrue(order.isActive);
        assertEq(order.remainingAmount, sourceAmount);
        assertEq(order.isNativeEth, true); // Native ETH order
        assertEq(order.totalFills, 0);
        assertEq(order.auctionConfig.auctionStartTime, startTime);
        assertEq(order.auctionConfig.auctionEndTime, endTime);
        assertEq(order.crossChainConfig.suiOrderHash, "sui_order_eth_123");
        assertEq(order.crossChainConfig.timelockDuration, 3600);
    }
    
    function testCreateCrossChainOrderInvalidSourceAmount() public {
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshCrossChainOrder.InvalidSourceAmount.selector);
        crossChainOrder.createCrossChainOrder(
            100, // Too small (< 0.001 WETH)
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
    }
    
    function testCreateCrossChainOrderExcessiveSourceAmount() public {
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        // Mock insufficient allowance for large amount
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.allowance.selector, maker, address(crossChainOrder)),
            abi.encode(1500e18) // Large amount
        );
        
        vm.prank(maker);
        vm.expectRevert(IMeshCrossChainOrder.ExcessiveSourceAmount.selector);
        crossChainOrder.createCrossChainOrder(
            1500e18, // > 1000 WETH maximum
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
    }
    
    function testCreateCrossChainOrderInvalidDestinationAmount() public {
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshCrossChainOrder.InvalidDestinationAmount.selector);
        crossChainOrder.createCrossChainOrder(
            sourceAmount,
            0, // Invalid destination amount
            auctionConfig,
            crossChainConfig
        );
    }
    
    function testCreateCrossChainOrderInvalidTimelockDuration() public {
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 100000, // > 24 hours maximum
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        vm.expectRevert(IMeshCrossChainOrder.InvalidTimelockDuration.selector);
        crossChainOrder.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
    }
    
    function testFillCrossChainOrder() public {
        // Create order first
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        bytes32 orderHash = crossChainOrder.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
        
        // Move to auction time
        vm.warp(startTime + 100);
        
        bytes32 secret = keccak256("test_secret");
        uint256 fillAmount = 5e18;
        string memory suiTxHash = "sui_tx_hash_123";
        
        vm.prank(resolver);
        uint256 filledAmount = crossChainOrder.fillCrossChainOrder(
            orderHash,
            secret,
            fillAmount,
            suiTxHash
        );
        
        assertEq(filledAmount, fillAmount);
        
        // Verify order state was updated
        IMeshCrossChainOrder.CrossChainOrder memory order = crossChainOrder.getCrossChainOrder(orderHash);
        assertEq(order.totalFills, 1);
        assertEq(order.remainingAmount, sourceAmount - fillAmount);
    }
    
    function testFillCrossChainOrderNotFound() public {
        bytes32 nonExistentOrderHash = keccak256("non_existent");
        
        vm.prank(resolver);
        vm.expectRevert(IMeshCrossChainOrder.OrderNotFound.selector);
        crossChainOrder.fillCrossChainOrder(
            nonExistentOrderHash,
            keccak256("test_secret"),
            5e18,
            "sui_tx_hash"
        );
    }
    
    function testCancelCrossChainOrder() public {
        // Create order first
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        bytes32 orderHash = crossChainOrder.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
        
        vm.prank(maker);
        vm.expectEmit(true, true, false, false);
        emit CrossChainOrderCancelled(orderHash, maker);
        
        crossChainOrder.cancelCrossChainOrder(orderHash);
        
        // Verify order is cancelled
        assertFalse(crossChainOrder.isCrossChainOrderActive(orderHash));
        assertTrue(crossChainOrder.cancelledOrders(orderHash));
    }
    
    function testCancelCrossChainOrderNotMaker() public {
        // Create order first
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        bytes32 orderHash = crossChainOrder.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
        
        vm.prank(resolver); // Not the maker
        vm.expectRevert(IMeshCrossChainOrder.NotMaker.selector);
        crossChainOrder.cancelCrossChainOrder(orderHash);
    }
    
    function testIsCrossChainOrderActive() public {
        // Create order first
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        bytes32 orderHash = crossChainOrder.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
        
        // Should be active initially
        assertTrue(crossChainOrder.isCrossChainOrderActive(orderHash));
        
        // Should be inactive after auction end
        vm.warp(endTime + 100);
        assertFalse(crossChainOrder.isCrossChainOrderActive(orderHash));
        
        // Reset time and cancel
        vm.warp(startTime + 100);
        vm.prank(maker);
        crossChainOrder.cancelCrossChainOrder(orderHash);
        assertFalse(crossChainOrder.isCrossChainOrderActive(orderHash));
    }
    
    function testGetOrderStats() public {
        // Create order first
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: startTime,
            auctionEndTime: endTime,
            startRate: 3e18,
            endRate: 1e18
        });
        
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        vm.prank(maker);
        bytes32 orderHash = crossChainOrder.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
        
        vm.warp(startTime + 100);
        
        (uint256 totalFills, uint256 remainingAmount, uint256 timeRemaining) = 
            crossChainOrder.getOrderStats(orderHash);
        
        assertEq(totalFills, 0);
        assertEq(remainingAmount, sourceAmount);
        assertTrue(timeRemaining > 0);
    }
    
    function testValidateCrossChainConfig() public {
        // Valid config
        IMeshCrossChainOrder.CrossChainConfig memory validConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        assertTrue(crossChainOrder.validateCrossChainConfig(validConfig));
        
        // Invalid config - empty sui order hash
        IMeshCrossChainOrder.CrossChainConfig memory invalidConfig1 = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "",
            timelockDuration: 3600,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        assertFalse(crossChainOrder.validateCrossChainConfig(invalidConfig1));
        
        // Invalid config - zero timelock duration
        IMeshCrossChainOrder.CrossChainConfig memory invalidConfig2 = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 0,
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        assertFalse(crossChainOrder.validateCrossChainConfig(invalidConfig2));
        
        // Invalid config - excessive timelock duration
        IMeshCrossChainOrder.CrossChainConfig memory invalidConfig3 = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: "sui_order_123",
            timelockDuration: 100000, // > 24 hours
            destinationAddress: "0x1234567890abcdef",
            secretHash: keccak256("secret")
        });
        
        assertFalse(crossChainOrder.validateCrossChainConfig(invalidConfig3));
    }
    
    function testContractDependencies() public {
        assertEq(address(crossChainOrder.weth()), address(weth));
        assertEq(address(crossChainOrder.limitOrderProtocol()), limitOrderProtocol);
        assertEq(address(crossChainOrder.escrowContract()), escrowContract);
    }
    
    function testConstants() public {
        assertEq(crossChainOrder.MIN_ORDER_AMOUNT(), 1e15);
        assertEq(crossChainOrder.MAX_ORDER_AMOUNT(), 1000e18);
        assertEq(crossChainOrder.DEFAULT_TIMELOCK_DURATION(), 3600);
        assertEq(crossChainOrder.MAX_TIMELOCK_DURATION(), 86400);
    }
}