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
 * @title Test suite for Sui Resolver
 * @dev Tests the integration with official 1inch contracts
 */
contract SuiResolverTest is Test {
    using AddressLib for Address;
    using TimelocksLib for Timelocks;

    SuiResolver public suiResolver;
    IEscrowFactory public mockEscrowFactory;
    IERC20 public mockAccessToken;
    
    address public constant MAKER = address(0x1);
    address public constant TAKER = address(0x2);
    address public constant RELAYER = address(0x3);
    address public constant TOKEN = address(0x4);
    
    uint256 public constant AMOUNT = 1 ether;
    uint256 public constant SAFETY_DEPOSIT = 0.1 ether;
    bytes32 public constant SECRET = keccak256("test-secret");
    bytes32 public constant SECRET_HASH = keccak256(abi.encodePacked(SECRET));
    bytes32 public constant ORDER_HASH = keccak256("test-order");

    function setUp() public {
        // Deploy mock contracts
        mockEscrowFactory = IEscrowFactory(address(0x100));
        mockAccessToken = IERC20(address(0x200));
        
        // Deploy Sui Resolver
        suiResolver = new SuiResolver(mockEscrowFactory, mockAccessToken);
        
        // Set relayer
        suiResolver.setRelayer(RELAYER);
    }

    function testConstructor() public view {
        assertEq(address(suiResolver.escrowFactory()), address(mockEscrowFactory));
        assertEq(address(suiResolver.accessToken()), address(mockAccessToken));
        assertEq(suiResolver.relayer(), RELAYER);
    }

    function testSetRelayer() public {
        address newRelayer = address(0x999);
        suiResolver.setRelayer(newRelayer);
        assertEq(suiResolver.relayer(), newRelayer);
    }

    function testSetRelayerOnlyOwner() public {
        address newRelayer = address(0x999);
        
        vm.prank(TAKER);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", TAKER));
        suiResolver.setRelayer(newRelayer);
    }

    function testCompleteSuiSwap() public {
        // Create timelocks with relative time (1 hour cancellation period)
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour relative offset
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        // Create mock immutables for the swap
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
        
        // Call deploySrc to create the swap
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        }), 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Complete the swap
        vm.prank(RELAYER);
        suiResolver.completeSuiSwap(ORDER_HASH, SECRET);
        
        // Verify the swap is completed
        SuiResolver.SuiSwap memory completedSwap = suiResolver.getSuiSwap(ORDER_HASH);
        assertTrue(completedSwap.completed);
    }

    function testCompleteSuiSwapOnlyRelayer() public {
        vm.prank(TAKER);
        vm.expectRevert("Only relayer can call this function");
        suiResolver.completeSuiSwap(ORDER_HASH, SECRET);
    }

    function testCompleteSuiSwapInvalidSecret() public {
        // Create timelocks with relative time (1 hour cancellation period)
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour relative offset
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        // Create mock immutables for the swap
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
        
        // Call deploySrc to create the swap
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        }), 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        bytes32 wrongSecret = keccak256("wrong-secret");
        
        vm.prank(RELAYER);
        vm.expectRevert("Invalid secret");
        suiResolver.completeSuiSwap(ORDER_HASH, wrongSecret);
    }

    function testCancelSuiSwap() public {
        // Create timelocks with relative time (1 hour cancellation period)
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour relative offset
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        // Create mock immutables for the swap
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
        
        // Call deploySrc to create the swap
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        }), 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Warp time to after cancellation period
        vm.warp(block.timestamp + 3601); // Just past the cancellation time
        
        // Cancel the swap as maker
        vm.prank(MAKER);
        suiResolver.cancelSuiSwap(ORDER_HASH);
        
        // Verify the swap is cancelled
        SuiResolver.SuiSwap memory cancelledSwap = suiResolver.getSuiSwap(ORDER_HASH);
        assertTrue(cancelledSwap.cancelled);
    }

    function testCancelSuiSwapNotExpired() public {
        // Create timelocks with relative time (1 hour cancellation period)
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour relative offset
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        // Create mock immutables for the swap with non-expired timelock
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
        
        // Call deploySrc to create the swap
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        }), 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Try to cancel the swap
        vm.prank(MAKER);
        vm.expectRevert("Swap not expired yet");
        suiResolver.cancelSuiSwap(ORDER_HASH);
    }

    function testCancelSuiSwapUnauthorized() public {
        // Create timelocks with relative time (1 hour cancellation period)
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour relative offset
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        // Create mock immutables for the swap
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
        
        // Call deploySrc to create the swap
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        }), 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        // Warp time to after cancellation period
        vm.warp(block.timestamp + 3601); // Just past the cancellation time
        
        // Try to cancel as unauthorized user
        address unauthorized = address(0x999);
        vm.prank(unauthorized);
        vm.expectRevert("Only maker or taker can cancel");
        suiResolver.cancelSuiSwap(ORDER_HASH);
    }

    function testIsSuiSwapActive() public {
        // Test with non-existent swap
        assertFalse(suiResolver.isSuiSwapActive(ORDER_HASH));
        
        // Create timelocks with relative time (1 hour cancellation period)
        uint256 deployedAt = block.timestamp;
        uint256 cancellationOffset = 3600; // 1 hour relative offset
        Timelocks timelocks = Timelocks.wrap((deployedAt << 224) | (cancellationOffset << (uint256(TimelocksLib.Stage.SrcCancellation) * 32)));
        
        // Create mock immutables for an active swap
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
        
        // Call deploySrc to create the swap
        vm.prank(MAKER);
        suiResolver.deploySrc(immutables, IOrderMixin.Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(MAKER))),
            receiver: Address.wrap(uint256(uint160(TAKER))),
            makerAsset: Address.wrap(uint256(uint160(TOKEN))),
            takerAsset: Address.wrap(uint256(uint160(TOKEN))),
            makingAmount: AMOUNT,
            takingAmount: AMOUNT,
            makerTraits: MakerTraits.wrap(0)
        }), 0, 0, AMOUNT, TakerTraits.wrap(0), "");
        
        assertTrue(suiResolver.isSuiSwapActive(ORDER_HASH));
    }

    function testRescueTokens() public {
        address token = address(0x123);
        uint256 amount = 1000;
        
        // Mock the token transfer
        vm.mockCall(
            token,
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), amount),
            abi.encode(true)
        );
        
        suiResolver.rescueTokens(IERC20(token), amount);
    }

    function testRescueTokensOnlyOwner() public {
        address token = address(0x123);
        uint256 amount = 1000;
        
        vm.prank(TAKER);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", TAKER));
        suiResolver.rescueTokens(IERC20(token), amount);
    }

    function testRescueETH() public {
        // Give ETH to the contract
        vm.deal(address(suiResolver), 1 ether);
        
        uint256 balanceBefore = address(this).balance;
        suiResolver.rescueETH();
        uint256 balanceAfter = address(this).balance;
        
        assertEq(balanceAfter - balanceBefore, 1 ether);
    }
    
    // Add receive function to accept ETH transfers
    receive() external payable {}

    function testRescueETHOnlyOwner() public {
        vm.prank(TAKER);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", TAKER));
        suiResolver.rescueETH();
    }

    function testArbitraryCalls() public {
        address target = address(0x123);
        bytes memory data = abi.encodeWithSignature("test()");
        
        // Mock the call to succeed
        vm.mockCall(target, data, abi.encode());
        
        address[] memory targets = new address[](1);
        targets[0] = target;
        
        bytes[] memory arguments = new bytes[](1);
        arguments[0] = data;
        
        suiResolver.arbitraryCalls(targets, arguments);
    }

    function testArbitraryCallsLengthMismatch() public {
        address[] memory targets = new address[](1);
        bytes[] memory arguments = new bytes[](2);
        
        vm.expectRevert();
        suiResolver.arbitraryCalls(targets, arguments);
    }

    function testArbitraryCallsOnlyOwner() public {
        address target = address(0x123);
        bytes memory data = abi.encodeWithSignature("test()");
        
        address[] memory targets = new address[](1);
        targets[0] = target;
        
        bytes[] memory arguments = new bytes[](1);
        arguments[0] = data;
        
        vm.prank(TAKER);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", TAKER));
        suiResolver.arbitraryCalls(targets, arguments);
    }
} 