// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMeshResolverNetwork
 * @dev Interface for Mesh Resolver Network (1inch Fusion+)
 */
interface IMeshResolverNetwork {
    // Structs
    struct Resolver {
        address resolver;
        uint256 stake;
        uint256 reputation;
        bool isAuthorized;
        uint256 totalFills;
        uint256 totalVolume;
        uint256 lastActive;
    }

    struct OrderInfo {
        bytes32 orderHash;
        uint256 sourceAmount;
        uint256 destinationAmount;
        uint256 totalFills;
        uint256 totalVolume;
        bool isActive;
    }

    // Events
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

    event ResolverUnregistered(
        address indexed resolver,
        uint256 stakeReturned,
        uint256 rewards
    );

    event PenaltyApplied(
        address indexed resolver,
        uint256 penaltyAmount,
        uint256 newReputation
    );

    event RewardsDistributed(
        address indexed resolver,
        uint256 rewardAmount
    );

    // Errors
    error OnlyLimitOrderProtocol();
    error ResolverAlreadyRegistered();
    error ResolverNotFound();
    error InsufficientStake();
    error UnauthorizedResolver();
    error OrderNotFound();
    error OrderNotActive();
    error ExcessiveStake();
    error InsufficientAllowance();
    error OrderAlreadyRegistered();
    error TransferFailed();

    // Functions
    function registerResolver(uint256 stake) external;

    function registerResolverWithEth() external payable;

    function authorizeResolver(address resolver, bool authorized) external;

    function unregisterResolver() external;

    function unregisterResolverWithEth() external;

    function registerOrder(
        bytes32 orderHash,
        uint256 sourceAmount,
        uint256 destinationAmount
    ) external;

    function recordOrderFill(
        address resolver,
        uint256 fillAmount,
        uint256 rate
    ) external;

    function isAuthorized(address resolver) external view returns (bool authorized);

    function getResolver(address resolver) external view returns (Resolver memory resolverInfo);

    function getOrder(bytes32 orderHash) external view returns (OrderInfo memory orderInfo);
} 