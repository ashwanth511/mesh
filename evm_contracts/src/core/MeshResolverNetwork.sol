// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

// WETH interface for deposit/withdraw functionality
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IMeshResolverNetwork} from "../interfaces/IMeshResolverNetwork.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title MeshResolverNetwork
 * @dev Enhanced resolver network for Mesh 1inch Fusion+ automated order execution
 * Manages resolver authorization, bidding, and execution coordination with improvements
 */
contract MeshResolverNetwork is ReentrancyGuard, Ownable, IMeshResolverNetwork {
    using SafeERC20 for IERC20;

    // State variables
    mapping(address => Resolver) public resolvers;
    mapping(bytes32 => OrderInfo) public orders;
    mapping(bytes32 => mapping(address => uint256)) public orderBids;
    mapping(bytes32 => address[]) public orderResolvers;
    mapping(address => uint256) public resolverStakes;
    mapping(address => uint256) public resolverReputation;

    // Configuration
    address public immutable limitOrderProtocol;
    IWETH public immutable weth;
    uint256 public constant MIN_STAKE = 0.001e18; // 0.001 WETH minimum stake (very low!)
    uint256 public constant MAX_STAKE = 10e18; // 10 WETH maximum stake
    uint256 public constant REPUTATION_DECAY_RATE = 99; // 1% decay per period
    uint256 public constant REPUTATION_PERIOD = 86400; // 24 hours
    uint256 public constant MIN_REPUTATION = 50; // Minimum reputation to be authorized
    uint256 public constant MAX_REPUTATION = 1000; // Maximum reputation

    // Enhanced features
    uint256 public totalStaked;
    uint256 public totalResolvers;
    uint256 public totalOrders;
    uint256 public totalVolume;

    modifier onlyLimitOrderProtocol() {
        if (msg.sender != limitOrderProtocol) revert OnlyLimitOrderProtocol();
        _;
    }

    constructor(address _limitOrderProtocol, address _weth, address initialOwner) Ownable(initialOwner) {
        limitOrderProtocol = _limitOrderProtocol;
        weth = IWETH(_weth);
    }

    /**
     * @dev Registers a resolver with WETH stake (very low minimum!)
     */
    function registerResolver(uint256 stake) external nonReentrant {
        if (resolvers[msg.sender].resolver != address(0)) revert ResolverAlreadyRegistered();
        if (stake < MIN_STAKE) revert InsufficientStake();
        if (stake > MAX_STAKE) revert ExcessiveStake();
        
        // Check WETH allowance
        uint256 allowance = weth.allowance(msg.sender, address(this));
        if (allowance < stake) revert InsufficientAllowance();

        // Transfer stake
        IERC20(address(weth)).safeTransferFrom(msg.sender, address(this), stake);
        resolverStakes[msg.sender] = stake;
        totalStaked += stake;

        resolvers[msg.sender] = Resolver({
            resolver: msg.sender,
            stake: stake,
            reputation: 100, // Start with neutral reputation
            isAuthorized: true,
            totalFills: 0,
            totalVolume: 0,
            lastActive: block.timestamp
        });

        totalResolvers++;

        emit ResolverRegistered(msg.sender, stake);
    }

    /**
     * @dev Registers a resolver with native ETH (very low minimum!)
     */
    function registerResolverWithEth() external payable nonReentrant {
        if (resolvers[msg.sender].resolver != address(0)) revert ResolverAlreadyRegistered();
        if (msg.value < MIN_STAKE) revert InsufficientStake();
        if (msg.value > MAX_STAKE) revert ExcessiveStake();
        
        // Convert ETH to WETH internally
        weth.deposit{value: msg.value}();
        resolverStakes[msg.sender] = msg.value;
        totalStaked += msg.value;

        resolvers[msg.sender] = Resolver({
            resolver: msg.sender,
            stake: msg.value,
            reputation: 100, // Start with neutral reputation
            isAuthorized: true,
            totalFills: 0,
            totalVolume: 0,
            lastActive: block.timestamp
        });

        totalResolvers++;

        emit ResolverRegistered(msg.sender, msg.value);
    }

    /**
     * @dev Unregisters a resolver and returns their stake
     */
    function unregisterResolver() external nonReentrant {
        Resolver storage resolver = resolvers[msg.sender];
        
        if (resolver.resolver == address(0)) revert ResolverNotFound();
        
        uint256 stakeToReturn = resolverStakes[msg.sender];
        uint256 rewards = 0; // Rewards would be tracked separately
        
        // Mark as unregistered
        resolver.isAuthorized = false;
        resolverStakes[msg.sender] = 0;
        totalStaked -= stakeToReturn;

        // Return stake and rewards
        if (stakeToReturn > 0) {
            IERC20(address(weth)).safeTransfer(msg.sender, stakeToReturn);
        }
        if (rewards > 0) {
            IERC20(address(weth)).safeTransfer(msg.sender, rewards);
        }

        totalResolvers--;

        emit ResolverUnregistered(msg.sender, stakeToReturn, rewards);
    }

    /**
     * @dev Unregisters a resolver and returns their stake as ETH
     */
    function unregisterResolverWithEth() external nonReentrant {
        Resolver storage resolver = resolvers[msg.sender];
        
        if (resolver.resolver == address(0)) revert ResolverNotFound();
        
        uint256 stakeToReturn = resolverStakes[msg.sender];
        uint256 rewards = 0; // Rewards would be tracked separately
        
        // Mark as unregistered
        resolver.isAuthorized = false;
        resolverStakes[msg.sender] = 0;
        totalStaked -= stakeToReturn;

        // Convert WETH back to ETH and return
        if (stakeToReturn > 0) {
            weth.withdraw(stakeToReturn);
            (bool success, ) = payable(msg.sender).call{value: stakeToReturn}("");
            if (!success) revert TransferFailed();
        }
        if (rewards > 0) {
            weth.withdraw(rewards);
            (bool success, ) = payable(msg.sender).call{value: rewards}("");
            if (!success) revert TransferFailed();
        }

        totalResolvers--;

        emit ResolverUnregistered(msg.sender, stakeToReturn, rewards);
    }

    /**
     * @dev Authorizes or deauthorizes a resolver (admin only)
     */
    function authorizeResolver(address resolver, bool authorized) external onlyOwner {
        if (resolvers[resolver].resolver == address(0)) revert ResolverNotFound();
        
        resolvers[resolver].isAuthorized = authorized;
        
        emit ResolverAuthorized(resolver, authorized);
    }

    /**
     * @dev Registers an order with enhanced tracking
     */
    function registerOrder(
        bytes32 orderHash,
        uint256 sourceAmount,
        uint256 destinationAmount
    ) external onlyLimitOrderProtocol {
        if (orders[orderHash].orderHash != bytes32(0)) revert OrderAlreadyRegistered();

        orders[orderHash] = OrderInfo({
            orderHash: orderHash,
            sourceAmount: sourceAmount,
            destinationAmount: destinationAmount,
            totalFills: 0,
            totalVolume: 0,
            isActive: true
        });

        totalOrders++;

        emit OrderRegistered(orderHash, sourceAmount, destinationAmount);
    }

    /**
     * @dev Records an order fill with enhanced reputation system
     */
    function recordOrderFill(
        address resolver,
        uint256 fillAmount,
        uint256 rate
    ) external onlyLimitOrderProtocol {
        Resolver storage resolverInfo = resolvers[resolver];
        if (resolverInfo.resolver == address(0)) revert ResolverNotFound();
        if (!resolverInfo.isAuthorized) revert UnauthorizedResolver();

        // Update resolver stats
        resolverInfo.totalFills++;
        resolverInfo.totalVolume += fillAmount;
        resolverInfo.lastActive = block.timestamp;

        // Enhanced reputation system
        uint256 reputationGain = calculateReputationGain(fillAmount, rate);
        resolverInfo.reputation = Math.min(
            resolverInfo.reputation + reputationGain,
            MAX_REPUTATION
        );

        // Update global stats
        totalVolume += fillAmount;

        emit OrderFillRecorded(bytes32(0), resolver, fillAmount, rate);
    }

    /**
     * @dev Calculates reputation gain based on fill performance
     */
    function calculateReputationGain(uint256 fillAmount, uint256 rate) internal pure returns (uint256) {
        // Base reputation gain
        uint256 baseGain = 1;
        
        // Bonus for larger fills
        if (fillAmount >= 1e18) { // 1 WETH
            baseGain += 2;
        }
        if (fillAmount >= 10e18) { // 10 WETH
            baseGain += 5;
        }

        // Bonus for better rates (higher rate = better execution)
        if (rate > 1e18) { // Above 1:1 rate
            baseGain += 3;
        }

        return baseGain;
    }

    /**
     * @dev Applies penalty to a resolver
     */
    function applyPenalty(address resolver, uint256 penaltyAmount) external onlyOwner {
        Resolver storage resolverInfo = resolvers[resolver];
        if (resolverInfo.resolver == address(0)) revert ResolverNotFound();

        // Penalties would be tracked separately since not in interface struct
        resolverInfo.reputation = Math.max(
            resolverInfo.reputation - penaltyAmount,
            MIN_REPUTATION
        );

        // Deauthorize if reputation drops too low
        if (resolverInfo.reputation < MIN_REPUTATION) {
            resolverInfo.isAuthorized = false;
        }

        emit PenaltyApplied(resolver, penaltyAmount, resolverInfo.reputation);
    }

    /**
     * @dev Distributes rewards to resolvers
     */
    function distributeRewards(address resolver, uint256 rewardAmount) external onlyOwner {
        Resolver storage resolverInfo = resolvers[resolver];
        if (resolverInfo.resolver == address(0)) revert ResolverNotFound();

        // Rewards would be tracked separately since not in interface struct
        IERC20(address(weth)).safeTransfer(resolver, rewardAmount);

        emit RewardsDistributed(resolver, rewardAmount);
    }

    /**
     * @dev Checks if a resolver is authorized
     */
    function isAuthorized(address resolver) external view returns (bool authorized) {
        Resolver memory resolverInfo = resolvers[resolver];
        authorized = resolverInfo.isAuthorized && 
                    resolverInfo.reputation >= MIN_REPUTATION &&
                    resolverInfo.resolver != address(0);
    }

    /**
     * @dev Gets resolver information
     */
    function getResolver(address resolver) external view returns (Resolver memory resolverInfo) {
        resolverInfo = resolvers[resolver];
    }

    /**
     * @dev Gets order information
     */
    function getOrder(bytes32 orderHash) external view returns (OrderInfo memory orderInfo) {
        orderInfo = orders[orderHash];
    }

    /**
     * @dev Gets network statistics
     */
    function getNetworkStats() external view returns (
        uint256 totalStakedAmount,
        uint256 totalResolverCount,
        uint256 totalOrderCount,
        uint256 totalVolumeHandled
    ) {
        totalStakedAmount = totalStaked;
        totalResolverCount = totalResolvers;
        totalOrderCount = totalOrders;
        totalVolumeHandled = totalVolume;
    }

    /**
     * @dev Gets top resolvers by reputation
     */
    function getTopResolvers(uint256 count) external view returns (address[] memory topResolvers) {
        // This is a simplified implementation
        // In production, you'd want to maintain a sorted list
        topResolvers = new address[](count);
        // Implementation would iterate through resolvers and sort by reputation
    }

    // Enhanced events (events are defined in the interface)

    // Enhanced errors (errors are defined in the interface)
}

library Math {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
} 