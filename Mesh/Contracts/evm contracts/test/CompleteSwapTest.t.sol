// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {SuiResolver} from "../src/SuiResolver.sol";
import {IEscrowFactory} from "cross-chain-swap/interfaces/IEscrowFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBaseEscrow} from "cross-chain-swap/interfaces/IBaseEscrow.sol";
import {Timelocks, TimelocksLib} from "cross-chain-swap/libraries/TimelocksLib.sol";
import {Address, AddressLib} from "solidity-utils/contracts/libraries/AddressLib.sol";
import {IOrderMixin} from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {TakerTraits} from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import {MakerTraits} from "limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";

/**
 * @title Complete Swap Test Suite
 * @dev Tests the complete ETH ↔ SUI swap flow including edge cases
 */
contract CompleteSwapTest is Test {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    SuiResolver public suiResolver;
    IEscrowFactory public mockEscrowFactory;
    IERC20 public mockAccessToken;
    
    // Test addresses
    address public constant MAKER = address(0x1);
    address public constant TAKER = address(0x2);
    address public constant RELAYER = address(0x3);
    address public constant TOKEN = address(0x4);
    address public constant CALLER = address(0x5);
    
    // Test values
    uint256 public constant AMOUNT = 0.003 ether; // 0.003 ETH
    uint256 public constant SAFETY_DEPOSIT = 0.0001 ether; // 0.0001 ETH
    bytes32 public constant SECRET = keccak256("test-secret-123");
    bytes32 public constant SECRET_HASH = keccak256(abi.encodePacked(SECRET));
    bytes32 public constant ORDER_HASH = keccak256("test-order-456");

    function setUp() public {
        // Deploy mock contracts
        mockEscrowFactory = IEscrowFactory(address(0x100));
        mockAccessToken = IERC20(address(0x200));
        
        // Deploy Sui Resolver
        suiResolver = new SuiResolver(mockEscrowFactory, mockAccessToken);
        
        // Set relayer
        suiResolver.setRelayer(RELAYER);
        
        // Fund test accounts
        vm.deal(MAKER, 10 ether);
        vm.deal(TAKER, 10 ether);
        vm.deal(RELAYER, 10 ether);
    }

    // ===== ETH to  SUI SWAP TESTS =====

    function testEthToSuiSwapComplete() public {
        console.log(" Testing complete ETH to SUI swap flow");
        
        // 1. Create timelocks
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        // 2. Create immutables
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        // 3. Create order
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        // 4. Deploy source escrow (ETH side)
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, order, 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // 5. Verify swap was recorded
        SuiResolver.SuiSwap memory swap = suiResolver.getSuiSwap(ORDER_HASH);
        assertEq(swap.maker, MAKER, "Maker should be set");
        assertEq(swap.taker, TAKER, "Taker should be set");
        assertEq(swap.amount, AMOUNT, "Amount should be 0.003 ETH");
        assertEq(swap.secretHash, SECRET_HASH, "Secret hash should match");
        assertFalse(swap.completed, "Swap should not be completed");
        assertFalse(swap.cancelled, "Swap should not be cancelled");
        
        // 6. Complete swap with secret (relayer)
        vm.prank(RELAYER);
        suiResolver.completeSuiSwap(ORDER_HASH, SECRET);
        
        // 7. Verify swap completed
        swap = suiResolver.getSuiSwap(ORDER_HASH);
        assertTrue(swap.completed, "Swap should be completed");
        assertFalse(swap.cancelled, "Swap should not be cancelled");
        
        console.log(" ETH to SUI swap completed successfully");
    }

    function testEthToSuiSwapInvalidSecret() public {
        console.log("Testing ETH to SUI swap with invalid secret");
        
        // Setup swap
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600;
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, order, 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Try to complete with wrong secret
        bytes32 wrongSecret = keccak256("wrong-secret");
        vm.prank(RELAYER);
        vm.expectRevert("Invalid secret");
        suiResolver.completeSuiSwap(ORDER_HASH, wrongSecret);
        
        console.log(" Invalid secret correctly rejected");
    }

    function testEthToSuiSwapExpired() public {
        console.log("Testing ETH to SUI swap expiration");
        
        // Setup swap with short timelock
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 1; // 1 second
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, order, 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Wait for expiration
        vm.warp(block.timestamp + 2);
        
        // Try to complete expired swap
        vm.prank(RELAYER);
        vm.expectRevert("Swap expired");
        suiResolver.completeSuiSwap(ORDER_HASH, SECRET);
        
        console.log(" Expired swap correctly rejected");
    }

    // ===== SUI to ETH SWAP TESTS =====

    function testSuiToEthSwapComplete() public {
        console.log("Testing complete SUI to ETH swap flow");
        
        // 1. Create timelocks
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600;
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.DstCancellation) * 32)));
        
        // 2. Create immutables
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        // 3. Mock the escrow factory call
        vm.mockCall(
            address(mockEscrowFactory),
            abi.encodeWithSelector(IEscrowFactory.createDstEscrow.selector),
            abi.encode()
        );
        
        // 4. Deploy destination escrow (ETH side)
        vm.prank(TAKER);
        suiResolver.deployDst{value: AMOUNT}(immutables, deployedAt);
        
        // 5. Verify swap was recorded
        SuiResolver.SuiSwap memory swap = suiResolver.getSuiSwap(ORDER_HASH);
        assertEq(swap.maker, MAKER, "Maker should be set");
        assertEq(swap.taker, TAKER, "Taker should be set");
        assertEq(swap.amount, AMOUNT, "Amount should be 0.003 ETH");
        assertEq(swap.secretHash, SECRET_HASH, "Secret hash should match");
        assertFalse(swap.completed, "Swap should not be completed");
        assertFalse(swap.cancelled, "Swap should not be cancelled");
        
        // 6. Complete swap with secret (relayer)
        vm.prank(RELAYER);
        suiResolver.completeSuiSwap(ORDER_HASH, SECRET);
        
        // 7. Verify swap completed
        swap = suiResolver.getSuiSwap(ORDER_HASH);
        assertTrue(swap.completed, "Swap should be completed");
        assertFalse(swap.cancelled, "Swap should not be cancelled");
        
        console.log(" SUI to ETH swap completed successfully");
    }

    // ===== CANCELLATION TESTS =====

    function testCancelSwapAfterExpiration() public {
        console.log(" Testing swap cancellation after expiration");
        
        // Setup swap with short timelock
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 1; // 1 second
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, order, 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Wait for expiration
        vm.warp(block.timestamp + 2);
        
        // Cancel as maker
        vm.prank(MAKER);
        suiResolver.cancelSuiSwap(ORDER_HASH);
        
        // Verify cancellation
        SuiResolver.SuiSwap memory swap = suiResolver.getSuiSwap(ORDER_HASH);
        assertTrue(swap.cancelled, "Swap should be cancelled");
        assertFalse(swap.completed, "Swap should not be completed");
        
        console.log(" Swap cancellation successful");
    }

    function testCancelSwapBeforeExpiration() public {
        console.log(" Testing swap cancellation before expiration");
        
        // Setup swap with long timelock
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, order, 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Try to cancel before expiration
        vm.prank(MAKER);
        vm.expectRevert("Swap not expired yet");
        suiResolver.cancelSuiSwap(ORDER_HASH);
        
        console.log(" Early cancellation correctly rejected");
    }

    // ===== ACCESS CONTROL TESTS =====

    function testOnlyRelayerCanComplete() public {
        console.log("Testing only relayer can complete swap");
        
        // Setup swap
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600;
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, order, 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Try to complete as non-relayer
        vm.prank(CALLER);
        vm.expectRevert("Only relayer can call this function");
        suiResolver.completeSuiSwap(ORDER_HASH, SECRET);
        
        console.log("Only relayer access correctly enforced");
    }

    // ===== EDGE CASE TESTS =====

    function testMinimumAmountValidation() public {
        console.log(" Testing minimum amount validation");
        
        uint256 smallAmount = 0.0001 ether; // Below minimum
        
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600;
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: smallAmount,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: smallAmount,
            takingAmount: smallAmount,
            makerTraits: MakerTraits.wrap(0)
        });
        
        vm.prank(MAKER);
        vm.expectRevert("Amount too low");
        suiResolver.deploySrc(immutables, order, 0, 0, smallAmount, TakerTraits.wrap(0), "");
        
        console.log(" Minimum amount validation working");
    }

    function testSwapStatusQueries() public {
        console.log(" Testing swap status queries");
        
        // Setup swap
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600;
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        IBaseEscrow.Immutables memory immutables = IBaseEscrow.Immutables({
            orderHash: ORDER_HASH,
            hashlock: SECRET_HASH,
            maker: Address.wrap(uint256(uint160(MAKER))),
            taker: Address.wrap(uint256(uint160(TAKER))),
            token: Address.wrap(uint256(uint160(TOKEN))),
            amount: AMOUNT,
            safetyDeposit: SAFETY_DEPOSIT,
            timelocks: timelocks
        });
        
        IOrderMixin.Order memory order = IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        });
        
        // Check non-existent swap
        assertFalse(suiResolver.isSuiSwapActive(ORDER_HASH), "Non-existent swap should be inactive");
        
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, order, 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Check active swap
        assertTrue(suiResolver.isSuiSwapActive(ORDER_HASH), "Active swap should be active");
        
        // Complete swap
        vm.prank(RELAYER);
        suiResolver.completeSuiSwap(ORDER_HASH, SECRET);
        
        // Check completed swap
        assertFalse(suiResolver.isSuiSwapActive(ORDER_HASH), "Completed swap should be inactive");
        
        console.log(" Swap status queries working correctly");
    }
} 