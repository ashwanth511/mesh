// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { IFusionPlus } from "../src/IFusionPlus.sol";
import { EscrowFactory } from "../src/EscrowFactory.sol";
import { FusionResolver } from "../src/FusionResolver.sol";

/**
 * @title FusionPlus Test Suite
 * @notice Comprehensive tests for the Fusion+ cross-chain swap contracts
 */
contract FusionPlusTest is Test {
    // ===== State Variables =====

    EscrowFactory public factory;
    FusionResolver public resolver;
    
    uint256 public AMOUNT;
    uint256 public SAFETY_DEPOSIT;
    bytes32 public SECRET;
    
    IFusionPlus.Timelocks public timelocks;
    IFusionPlus.Immutables public immutables;
    IFusionPlus.OrderConfig public orderConfig;
    IFusionPlus.FeeConfig public feeConfig;

    // ===== Setup =====

    function setUp() public {
        // Initialize test values
        AMOUNT = 1000;
        SAFETY_DEPOSIT = 100;
        SECRET = keccak256("test_secret");
        
        // Create timelocks
        timelocks = IFusionPlus.Timelocks({
            srcWithdrawal: 100,
            srcPublicWithdrawal: 200,
            srcCancellation: 300,
            srcPublicCancellation: 400,
            dstWithdrawal: 100,
            dstPublicWithdrawal: 200,
            dstCancellation: 300
        });

        // Create immutables
        immutables = IFusionPlus.Immutables({
            maker: address(0x1),
            taker: address(0x2),
            token: address(0), // Native token
            amount: AMOUNT,
            hashlock: keccak256(abi.encodePacked(SECRET)),
            timelocks: timelocks,
            safetyDeposit: SAFETY_DEPOSIT,
            deployedAt: 0
        });

        // Create fee config
        feeConfig = IFusionPlus.FeeConfig({
            protocolFee: 10,
            integratorFee: 5,
            surplusPercentage: 50,
            maxCancellationPremium: 100
        });

        // Create order config
        orderConfig = IFusionPlus.OrderConfig({
            id: 1,
            srcAmount: AMOUNT,
            minDstAmount: AMOUNT * 95 / 100, // 5% slippage
            estimatedDstAmount: AMOUNT,
            expirationTime: block.timestamp + 3600,
            srcAssetIsNative: true,
            dstAssetIsNative: true,
            fee: feeConfig,
            cancellationAuctionDuration: 300
        });

        // Deploy contracts
        factory = new EscrowFactory();
        resolver = new FusionResolver(payable(address(factory)));

        // Setup test accounts
        vm.deal(address(0x1), 10000 ether);
        vm.deal(address(0x2), 10000 ether);
    }

    // ===== Tests =====

    function testFactoryDeployment() public view {
        assertTrue(address(factory.escrowSrc()) != address(0x0));
        assertTrue(address(factory.escrowDst()) != address(0x0));
    }

    function testResolverDeployment() public view {
        assertEq(address(resolver.escrowFactory()), address(factory));
    }

    function testComputeOrderHash() public view {
        bytes32 hash = factory.computeOrderHash(orderConfig, immutables);
        assertTrue(hash != bytes32(0));
    }

    function testInitiateEthereumToSuiSwap() public {
        vm.startPrank(address(0x2));
        vm.deal(address(0x2), SAFETY_DEPOSIT);
        
        resolver.initiateEthereumToSuiSwap{value: SAFETY_DEPOSIT}(orderConfig, immutables);
        
        bytes32 orderHash = factory.computeOrderHash(orderConfig, immutables);
        assertTrue(resolver.getSwap(orderHash).createdAt > 0);
        assertTrue(resolver.getSwap(orderHash).isEthereumToSui);
        assertFalse(resolver.getSwap(orderHash).isCompleted);
        
        vm.stopPrank();
    }

    function testInitiateSuiToEthereumSwap() public {
        vm.startPrank(address(0x2));
        vm.deal(address(0x2), SAFETY_DEPOSIT);
        
        resolver.initiateSuiToEthereumSwap{value: SAFETY_DEPOSIT}(orderConfig, immutables);
        
        bytes32 orderHash = factory.computeOrderHash(orderConfig, immutables);
        assertTrue(resolver.getSwap(orderHash).createdAt > 0);
        assertFalse(resolver.getSwap(orderHash).isEthereumToSui);
        assertFalse(resolver.getSwap(orderHash).isCompleted);
        
        vm.stopPrank();
    }

    function testSetSuiEscrow() public {
        vm.startPrank(address(0x2));
        vm.deal(address(0x2), SAFETY_DEPOSIT);
        
        resolver.initiateEthereumToSuiSwap{value: SAFETY_DEPOSIT}(orderConfig, immutables);
        
        bytes32 orderHash = factory.computeOrderHash(orderConfig, immutables);
        address suiEscrow = address(0x123);
        
        vm.stopPrank();
        
        // Use the test contract (which is authorized) to set the Sui escrow
        resolver.setSuiEscrow(orderHash, suiEscrow);
        assertEq(resolver.getSwap(orderHash).suiEscrow, suiEscrow);
    }

    function testAuthorizedResolver() public {
        assertTrue(resolver.isAuthorizedResolver(address(this)));
        
        address newResolver = address(0x999);
        resolver.addAuthorizedResolver(newResolver);
        assertTrue(resolver.isAuthorizedResolver(newResolver));
        
        resolver.removeAuthorizedResolver(newResolver);
        assertFalse(resolver.isAuthorizedResolver(newResolver));
    }
} 