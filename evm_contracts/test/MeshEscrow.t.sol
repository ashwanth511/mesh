// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MeshEscrow} from "../src/MeshEscrow.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

contract MeshEscrowTest is Test {
    MeshEscrow public escrow;
    IERC20 public weth;
    
    address public maker = address(0x1);
    address payable public taker = payable(address(0x2));
    address public resolver = address(0x3);
    address public owner = address(0x4);
    
    bytes32 public hashLock;
    bytes32 public secret;
    uint256 public timeLock;
    uint256 public amount = 1 ether;
    
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
    
    function setUp() public {
        // Deploy mock WETH
        weth = IERC20(address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)); // Sepolia WETH
        
        // Deploy escrow
        escrow = new MeshEscrow(address(weth), owner);
        
        // Generate test secret and hash lock
        secret = keccak256(abi.encodePacked("test_secret"));
        hashLock = keccak256(abi.encodePacked(secret));
        timeLock = block.timestamp + 1 hours;
        
        // Fund accounts
        vm.deal(maker, 10 ether);
        vm.deal(taker, 10 ether);
        vm.deal(resolver, 10 ether);
        
        // Mock WETH balance and allowance
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.allowance.selector, maker, address(escrow)),
            abi.encode(amount)
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
    }
    
    // ========== WETH TESTS ==========
    
    function testCreateEscrowWeth() public {
        vm.startPrank(maker);
        
        bytes32 escrowId = escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            amount
        );
        
        vm.stopPrank();
        
        // Verify escrow was created
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.maker, maker);
        assertEq(escrowData.taker, taker);
        assertEq(escrowData.totalAmount, amount);
        assertEq(escrowData.remainingAmount, amount);
        assertEq(escrowData.hashLock, hashLock);
        assertEq(escrowData.timeLock, timeLock);
        assertEq(escrowData.completed, false);
        assertEq(escrowData.refunded, false);
        assertEq(escrowData.isNativeEth, false); // WETH escrow
        assertEq(escrowData.suiOrderHash, "sui_order_hash_123");
    }
    
    function testFillEscrowWeth() public {
        // Create escrow
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            amount
        );
        vm.stopPrank();
        
        // Fill escrow
        vm.startPrank(taker);
        uint256 filledAmount = escrow.fillEscrow(escrowId, secret);
        vm.stopPrank();
        
        assertEq(filledAmount, amount);
        
        // Verify escrow was filled
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.completed, true);
        assertEq(escrowData.remainingAmount, 0);
        assertEq(escrowData.secret, secret);
    }
    
    function testRefundEscrowWeth() public {
        // Create escrow
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            amount
        );
        vm.stopPrank();
        
        // Fast forward past time lock
        vm.warp(timeLock + 1);
        
        // Refund escrow
        vm.startPrank(maker);
        uint256 refundedAmount = escrow.refundEscrow(escrowId);
        vm.stopPrank();
        
        assertEq(refundedAmount, amount);
        
        // Verify escrow was refunded
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.refunded, true);
        assertEq(escrowData.remainingAmount, 0);
    }
    
    // ========== NATIVE ETH TESTS ==========
    
    function testCreateEscrowWithEth() public {
        vm.startPrank(maker);
        
        bytes32 escrowId = escrow.createEscrowWithEth{value: amount}(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_eth_123"
        );
        
        vm.stopPrank();
        
        // Verify escrow was created
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.maker, maker);
        assertEq(escrowData.taker, taker);
        assertEq(escrowData.totalAmount, amount);
        assertEq(escrowData.remainingAmount, amount);
        assertEq(escrowData.hashLock, hashLock);
        assertEq(escrowData.timeLock, timeLock);
        assertEq(escrowData.completed, false);
        assertEq(escrowData.refunded, false);
        assertEq(escrowData.isNativeEth, true); // Native ETH escrow
        assertEq(escrowData.suiOrderHash, "sui_order_hash_eth_123");
    }
    
    function testFillEscrowWithEth() public {
        // Create escrow with ETH
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrowWithEth{value: amount}(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_eth_123"
        );
        vm.stopPrank();
        
        // Record initial balance
        uint256 initialBalance = taker.balance;
        
        // Fill escrow
        vm.startPrank(taker);
        uint256 filledAmount = escrow.fillEscrow(escrowId, secret);
        vm.stopPrank();
        
        assertEq(filledAmount, amount);
        
        // Verify ETH was transferred
        assertEq(taker.balance, initialBalance + amount);
        
        // Verify escrow was filled
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.completed, true);
        assertEq(escrowData.remainingAmount, 0);
        assertEq(escrowData.secret, secret);
    }
    
    function testRefundEscrowWithEth() public {
        // Create escrow with ETH
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrowWithEth{value: amount}(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_eth_123"
        );
        vm.stopPrank();
        
        // Record initial balance
        uint256 initialBalance = maker.balance;
        
        // Fast forward past time lock
        vm.warp(timeLock + 1);
        
        // Refund escrow
        vm.startPrank(maker);
        uint256 refundedAmount = escrow.refundEscrow(escrowId);
        vm.stopPrank();
        
        assertEq(refundedAmount, amount);
        
        // Verify ETH was refunded
        assertEq(maker.balance, initialBalance + amount);
        
        // Verify escrow was refunded
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.refunded, true);
        assertEq(escrowData.remainingAmount, 0);
    }
    
    function testCancelEscrowWithEth() public {
        // Create escrow with ETH
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrowWithEth{value: amount}(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_eth_123"
        );
        vm.stopPrank();
        
        // Record initial balance
        uint256 initialBalance = maker.balance;
        
        // Cancel escrow
        vm.startPrank(maker);
        uint256 cancelledAmount = escrow.cancelEscrow(escrowId);
        vm.stopPrank();
        
        assertEq(cancelledAmount, amount);
        
        // Verify ETH was returned
        assertEq(maker.balance, initialBalance + amount);
        
        // Verify escrow was cancelled
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.refunded, true);
        assertEq(escrowData.remainingAmount, 0);
    }
    
    // ========== PARTIAL FILL TESTS ==========
    
    function testFillEscrowPartialWeth() public {
        // Create escrow
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            amount
        );
        vm.stopPrank();
        
        uint256 partialAmount = amount / 2;
        
        // Fill escrow partially
        vm.startPrank(taker);
        uint256 filledAmount = escrow.fillEscrowPartial(escrowId, secret, partialAmount);
        vm.stopPrank();
        
        assertEq(filledAmount, partialAmount);
        
        // Verify escrow was partially filled
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.completed, false);
        assertEq(escrowData.remainingAmount, amount - partialAmount);
        assertEq(escrowData.secret, secret);
    }
    
    function testFillEscrowPartialWithEth() public {
        // Create escrow with ETH
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrowWithEth{value: amount}(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_eth_123"
        );
        vm.stopPrank();
        
        uint256 partialAmount = amount / 2;
        uint256 initialBalance = taker.balance;
        
        // Fill escrow partially
        vm.startPrank(taker);
        uint256 filledAmount = escrow.fillEscrowPartial(escrowId, secret, partialAmount);
        vm.stopPrank();
        
        assertEq(filledAmount, partialAmount);
        
        // Verify ETH was transferred
        assertEq(taker.balance, initialBalance + partialAmount);
        
        // Verify escrow was partially filled
        MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
        assertEq(escrowData.completed, false);
        assertEq(escrowData.remainingAmount, amount - partialAmount);
        assertEq(escrowData.secret, secret);
    }
    
    // ========== ERROR TESTS ==========
    
    function testCreateEscrowWithEthZeroAmount() public {
        vm.startPrank(maker);
        
        vm.expectRevert(MeshEscrow.InvalidAmount.selector);
        escrow.createEscrowWithEth{value: 0}(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_eth_123"
        );
        
        vm.stopPrank();
    }
    
    function testCreateEscrowWethZeroAmount() public {
        vm.startPrank(maker);
        
        vm.expectRevert(MeshEscrow.InvalidAmount.selector);
        escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            0
        );
        
        vm.stopPrank();
    }
    
    function testFillEscrowInvalidSecret() public {
        // Create escrow
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            amount
        );
        vm.stopPrank();
        
        // Try to fill with wrong secret
        vm.startPrank(taker);
        vm.expectRevert(MeshEscrow.InvalidSecret.selector);
        escrow.fillEscrow(escrowId, keccak256(abi.encodePacked("wrong_secret")));
        vm.stopPrank();
    }
    
    function testFillEscrowWithEthInvalidSecret() public {
        // Create escrow with ETH
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrowWithEth{value: amount}(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_eth_123"
        );
        vm.stopPrank();
        
        // Try to fill with wrong secret
        vm.startPrank(taker);
        vm.expectRevert(MeshEscrow.InvalidSecret.selector);
        escrow.fillEscrow(escrowId, keccak256(abi.encodePacked("wrong_secret")));
        vm.stopPrank();
    }
    
    // ========== UTILITY TESTS ==========
    
    function testEscrowExists() public {
        // Create escrow
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            amount
        );
        vm.stopPrank();
        
        assertTrue(escrow.escrowExists(escrowId));
        assertFalse(escrow.escrowExists(keccak256(abi.encodePacked("non_existent"))));
    }
    
    function testIsSecretUsed() public {
        // Create escrow
        vm.startPrank(maker);
        bytes32 escrowId = escrow.createEscrow(
            hashLock,
            timeLock,
            taker,
            "sui_order_hash_123",
            amount
        );
        vm.stopPrank();
        
        // Secret not used initially
        assertFalse(escrow.isSecretUsed(secret));
        
        // Fill escrow
        vm.startPrank(taker);
        escrow.fillEscrow(escrowId, secret);
        vm.stopPrank();
        
        // Secret now used
        assertTrue(escrow.isSecretUsed(secret));
    }
    
    function testRescueTokens() public {
        // Fund contract with some ETH
        vm.deal(address(escrow), 5 ether);
        
        // Rescue ETH
        vm.startPrank(owner);
        escrow.rescueTokens(address(0), owner, 2 ether);
        vm.stopPrank();
        
        // Verify ETH was rescued
        assertEq(owner.balance, 2 ether);
    }
    
    function testReceiveFunction() public {
        // Test that contract can receive ETH
        vm.deal(maker, 10 ether);
        
        vm.startPrank(maker);
        (bool success, ) = address(escrow).call{value: 1 ether}("");
        vm.stopPrank();
        
        assertTrue(success);
        assertEq(address(escrow).balance, 1 ether);
    }
} 