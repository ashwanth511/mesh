// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MeshResolverNetwork} from "../src/core/MeshResolverNetwork.sol";
import {IMeshResolverNetwork} from "../src/interfaces/IMeshResolverNetwork.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

// WETH interface for testing
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

contract MeshResolverNetworkTest is Test {
    MeshResolverNetwork public resolverNetwork;
    IWETH public weth;
    
    address public limitOrderProtocol = address(0x1);
    address public owner = address(0x2);
    address public resolver1 = address(0x3);
    address public resolver2 = address(0x4);
    
    uint256 public stake = 0.001e18; // 0.001 WETH (very low!)
    bytes32 public orderHash = keccak256("test_order");
    
    event ResolverRegistered(
        address indexed resolver,
        uint256 stake
    );
    
    event ResolverAuthorized(
        address indexed resolver,
        bool authorized
    );
    
    event OrderRegistered(
        bytes32 indexed orderHash,
        uint256 sourceAmount,
        uint256 destinationAmount
    );
    
    event OrderFillRecorded(
        bytes32 indexed orderHash,
        address indexed resolver,
        uint256 fillAmount,
        uint256 rate
    );
    
    function setUp() public {
        // Deploy mock WETH
        weth = IWETH(address(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)); // Sepolia WETH
        
        // Deploy resolver network
        resolverNetwork = new MeshResolverNetwork(limitOrderProtocol, address(weth), owner);
        
        // Fund accounts
        vm.deal(resolver1, 10 ether);
        vm.deal(resolver2, 10 ether);
        vm.deal(owner, 10 ether);
        
        // Mock WETH balance and allowance for resolvers
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.allowance.selector, resolver1, address(resolverNetwork)),
            abi.encode(stake)
        );
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.allowance.selector, resolver2, address(resolverNetwork)),
            abi.encode(stake)
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
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.withdraw.selector),
            abi.encode()
        );
    }
    
    function testRegisterResolver() public {
        vm.prank(resolver1);
        vm.expectEmit(true, false, false, true);
        emit ResolverRegistered(resolver1, stake);
        
        resolverNetwork.registerResolver(stake);
        
        // Verify resolver was registered
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertEq(resolverInfo.resolver, resolver1);
        assertEq(resolverInfo.stake, stake);
        assertEq(resolverInfo.reputation, 100);
        assertTrue(resolverInfo.isAuthorized);
        assertEq(resolverInfo.totalFills, 0);
        assertEq(resolverInfo.totalVolume, 0);
        assertEq(resolverInfo.lastActive, block.timestamp);
    }
    
    function testRegisterResolverInsufficientStake() public {
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.InsufficientStake.selector);
        resolverNetwork.registerResolver(0.0005e18); // Less than 0.001 WETH minimum
    }

    function testRegisterResolverWithEth() public {
        // Mock the deposit function to succeed
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        
        vm.prank(resolver1);
        vm.expectEmit(true, false, false, true);
        emit ResolverRegistered(resolver1, 0.001 ether);
        
        resolverNetwork.registerResolverWithEth{value: 0.001 ether}();
        
        // Verify resolver was registered
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertEq(resolverInfo.resolver, resolver1);
        assertEq(resolverInfo.stake, 0.001 ether);
        assertEq(resolverInfo.reputation, 100);
        assertTrue(resolverInfo.isAuthorized);
        assertEq(resolverInfo.totalFills, 0);
        assertEq(resolverInfo.totalVolume, 0);
        assertEq(resolverInfo.lastActive, block.timestamp);
    }

    function testRegisterResolverWithEthInsufficientStake() public {
        // Mock the deposit function to succeed
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.InsufficientStake.selector);
        resolverNetwork.registerResolverWithEth{value: 0.0005 ether}(); // Less than 0.001 WETH minimum
    }
    
    function testRegisterResolverExcessiveStake() public {
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.ExcessiveStake.selector);
        resolverNetwork.registerResolver(15e18); // More than 10 WETH maximum
    }

    function testRegisterResolverWithEthExcessiveStake() public {
        // Give resolver1 enough ETH
        vm.deal(resolver1, 15 ether);
        
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.ExcessiveStake.selector);
        resolverNetwork.registerResolverWithEth{value: 11 ether}(); // More than 10 WETH maximum
    }

    function testRegisterResolverWithEthAlreadyRegistered() public {
        // Mock the deposit function to succeed
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        
        // Register resolver first with ETH
        vm.prank(resolver1);
        resolverNetwork.registerResolverWithEth{value: 0.001 ether}();
        
        // Try to register again with ETH
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.ResolverAlreadyRegistered.selector);
        resolverNetwork.registerResolverWithEth{value: 0.001 ether}();
    }

    function testRegisterResolverWithEthVeryLowStake() public {
        // Mock the deposit function to succeed
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        
        // Test with exactly minimum stake
        vm.prank(resolver1);
        vm.expectEmit(true, false, false, true);
        emit ResolverRegistered(resolver1, 0.001 ether);
        
        resolverNetwork.registerResolverWithEth{value: 0.001 ether}();
        
        // Verify resolver was registered
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertEq(resolverInfo.resolver, resolver1);
        assertEq(resolverInfo.stake, 0.001 ether);
        assertTrue(resolverInfo.isAuthorized);
    }

    function testRegisterResolverWithEthHigherStake() public {
        // Mock the deposit function to succeed
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        
        // Test with higher stake
        vm.prank(resolver1);
        vm.expectEmit(true, false, false, true);
        emit ResolverRegistered(resolver1, 1 ether);
        
        resolverNetwork.registerResolverWithEth{value: 1 ether}();
        
        // Verify resolver was registered
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertEq(resolverInfo.resolver, resolver1);
        assertEq(resolverInfo.stake, 1 ether);
        assertTrue(resolverInfo.isAuthorized);
    }

    function testUnregisterResolverWithEth() public {
        // Mock the deposit and withdraw functions to succeed
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.withdraw.selector),
            abi.encode()
        );
        
        // Register resolver first with ETH
        vm.prank(resolver1);
        resolverNetwork.registerResolverWithEth{value: 0.001 ether}();
        
        // Unregister resolver and get ETH back
        vm.prank(resolver1);
        resolverNetwork.unregisterResolverWithEth();
        
        // Verify resolver is unregistered
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertFalse(resolverInfo.isAuthorized);
    }

    function testUnregisterResolverWithEthNotFound() public {
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.ResolverNotFound.selector);
        resolverNetwork.unregisterResolverWithEth();
    }

    function testMixedRegistration() public {
        // Mock the deposit function to succeed
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IWETH.deposit.selector),
            abi.encode()
        );
        
        // Register resolver1 with WETH
        vm.prank(resolver1);
        resolverNetwork.registerResolver(0.001 ether);
        
        // Register resolver2 with ETH
        vm.prank(resolver2);
        resolverNetwork.registerResolverWithEth{value: 0.001 ether}();
        
        // Both should be registered
        IMeshResolverNetwork.Resolver memory resolverInfo1 = resolverNetwork.getResolver(resolver1);
        IMeshResolverNetwork.Resolver memory resolverInfo2 = resolverNetwork.getResolver(resolver2);
        
        assertTrue(resolverInfo1.isAuthorized);
        assertTrue(resolverInfo2.isAuthorized);
        assertEq(resolverInfo1.stake, 0.001 ether);
        assertEq(resolverInfo2.stake, 0.001 ether);
    }
    
    function testRegisterResolverAlreadyRegistered() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        // Try to register again
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.ResolverAlreadyRegistered.selector);
        resolverNetwork.registerResolver(stake);
    }
    
    function testRegisterResolverInsufficientAllowance() public {
        // Mock insufficient allowance
        vm.mockCall(
            address(weth),
            abi.encodeWithSelector(IERC20.allowance.selector, resolver1, address(resolverNetwork)),
            abi.encode(stake - 1)
        );
        
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.InsufficientAllowance.selector);
        resolverNetwork.registerResolver(stake);
    }
    
    function testUnregisterResolver() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        // Unregister resolver
        vm.prank(resolver1);
        resolverNetwork.unregisterResolver();
        
        // Verify resolver is unregistered
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertFalse(resolverInfo.isAuthorized);
    }
    
    function testUnregisterResolverNotFound() public {
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.ResolverNotFound.selector);
        resolverNetwork.unregisterResolver();
    }
    
    function testAuthorizeResolver() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        // Authorize resolver (owner only)
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit ResolverAuthorized(resolver1, false);
        
        resolverNetwork.authorizeResolver(resolver1, false);
        
        // Verify authorization status
        assertFalse(resolverNetwork.isAuthorized(resolver1));
    }
    
    function testAuthorizeResolverOnlyOwner() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        // Try to authorize from non-owner
        vm.prank(resolver1);
        vm.expectRevert();
        resolverNetwork.authorizeResolver(resolver1, false);
    }
    
    function testRegisterOrder() public {
        uint256 sourceAmount = 10e18;
        uint256 destinationAmount = 20e18;
        
        vm.prank(limitOrderProtocol);
        vm.expectEmit(true, false, false, true);
        emit OrderRegistered(orderHash, sourceAmount, destinationAmount);
        
        resolverNetwork.registerOrder(orderHash, sourceAmount, destinationAmount);
        
        // Verify order was registered
        IMeshResolverNetwork.OrderInfo memory orderInfo = resolverNetwork.getOrder(orderHash);
        assertEq(orderInfo.orderHash, orderHash);
        assertEq(orderInfo.sourceAmount, sourceAmount);
        assertEq(orderInfo.destinationAmount, destinationAmount);
        assertEq(orderInfo.totalFills, 0);
        assertEq(orderInfo.totalVolume, 0);
        assertTrue(orderInfo.isActive);
    }
    
    function testRegisterOrderOnlyLimitOrderProtocol() public {
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.OnlyLimitOrderProtocol.selector);
        resolverNetwork.registerOrder(orderHash, 10e18, 20e18);
    }
    
    function testRegisterOrderAlreadyRegistered() public {
        // Register order first
        vm.prank(limitOrderProtocol);
        resolverNetwork.registerOrder(orderHash, 10e18, 20e18);
        
        // Try to register same order again
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshResolverNetwork.OrderAlreadyRegistered.selector);
        resolverNetwork.registerOrder(orderHash, 10e18, 20e18);
    }
    
    function testRecordOrderFill() public {
        // Register resolver and order first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        vm.prank(limitOrderProtocol);
        resolverNetwork.registerOrder(orderHash, 10e18, 20e18);
        
        uint256 fillAmount = 5e18;
        uint256 rate = 2e18;
        
        vm.prank(limitOrderProtocol);
        vm.expectEmit(true, true, false, true);
        emit OrderFillRecorded(bytes32(0), resolver1, fillAmount, rate);
        
        resolverNetwork.recordOrderFill(resolver1, fillAmount, rate);
        
        // Verify resolver stats were updated
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertEq(resolverInfo.totalFills, 1);
        assertEq(resolverInfo.totalVolume, fillAmount);
        assertTrue(resolverInfo.reputation > 100); // Should have gained reputation
    }
    
    function testRecordOrderFillOnlyLimitOrderProtocol() public {
        vm.prank(resolver1);
        vm.expectRevert(IMeshResolverNetwork.OnlyLimitOrderProtocol.selector);
        resolverNetwork.recordOrderFill(resolver1, 5e18, 2e18);
    }
    
    function testRecordOrderFillResolverNotFound() public {
        vm.prank(limitOrderProtocol);
        vm.expectRevert(IMeshResolverNetwork.ResolverNotFound.selector);
        resolverNetwork.recordOrderFill(resolver1, 5e18, 2e18);
    }
    
    function testIsAuthorized() public {
        // Initially not authorized (not registered)
        assertFalse(resolverNetwork.isAuthorized(resolver1));
        
        // Register resolver (becomes authorized by default)
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        assertTrue(resolverNetwork.isAuthorized(resolver1));
        
        // Deauthorize resolver
        vm.prank(owner);
        resolverNetwork.authorizeResolver(resolver1, false);
        assertFalse(resolverNetwork.isAuthorized(resolver1));
    }
    
    function testApplyPenalty() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        uint256 penaltyAmount = 20;
        uint256 initialReputation = 100;
        
        vm.prank(owner);
        resolverNetwork.applyPenalty(resolver1, penaltyAmount);
        
        // Verify reputation was reduced
        IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(resolver1);
        assertEq(resolverInfo.reputation, initialReputation - penaltyAmount);
    }
    
    function testApplyPenaltyOnlyOwner() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        vm.prank(resolver1);
        vm.expectRevert();
        resolverNetwork.applyPenalty(resolver1, 20);
    }
    
    function testApplyPenaltyResolverNotFound() public {
        vm.prank(owner);
        vm.expectRevert(IMeshResolverNetwork.ResolverNotFound.selector);
        resolverNetwork.applyPenalty(resolver1, 20);
    }
    
    function testDistributeRewards() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        uint256 rewardAmount = 1e18;
        
        vm.prank(owner);
        resolverNetwork.distributeRewards(resolver1, rewardAmount);
        
        // Verify WETH transfer was called
        // (In a real test, you'd check the actual balance change)
    }
    
    function testDistributeRewardsOnlyOwner() public {
        // Register resolver first
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        vm.prank(resolver1);
        vm.expectRevert();
        resolverNetwork.distributeRewards(resolver1, 1e18);
    }
    
    function testDistributeRewardsResolverNotFound() public {
        vm.prank(owner);
        vm.expectRevert(IMeshResolverNetwork.ResolverNotFound.selector);
        resolverNetwork.distributeRewards(resolver1, 1e18);
    }
    
    function testGetNetworkStats() public {
        // Register two resolvers
        vm.prank(resolver1);
        resolverNetwork.registerResolver(stake);
        
        vm.prank(resolver2);
        resolverNetwork.registerResolver(stake);
        
        // Register an order
        vm.prank(limitOrderProtocol);
        resolverNetwork.registerOrder(orderHash, 10e18, 20e18);
        
        // Record a fill
        vm.prank(limitOrderProtocol);
        resolverNetwork.recordOrderFill(resolver1, 5e18, 2e18);
        
        (uint256 totalStakedAmount, uint256 totalResolverCount, uint256 totalOrderCount, uint256 totalVolumeHandled) = 
            resolverNetwork.getNetworkStats();
        
        assertEq(totalStakedAmount, stake * 2);
        assertEq(totalResolverCount, 2);
        assertEq(totalOrderCount, 1);
        assertEq(totalVolumeHandled, 5e18);
    }
    
    function testGetTopResolvers() public {
        // This is a simplified test since the actual implementation is basic
        address[] memory topResolvers = resolverNetwork.getTopResolvers(5);
        assertEq(topResolvers.length, 5);
    }
}