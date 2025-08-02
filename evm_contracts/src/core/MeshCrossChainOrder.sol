// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IMeshCrossChainOrder} from "../interfaces/IMeshCrossChainOrder.sol";
import {IMeshLimitOrderProtocol} from "../interfaces/IMeshLimitOrderProtocol.sol";
import {IMeshEscrow} from "../interfaces/IMeshEscrow.sol";
import {HashLock} from "../utils/HashLock.sol";
import {TimeLock} from "../utils/TimeLock.sol";

/**
 * @title MeshCrossChainOrder
 * @dev Enhanced cross-chain order management for Mesh 1inch Fusion+
 * Combines limit orders with secure cross-chain execution
 */
contract MeshCrossChainOrder is ReentrancyGuard, IMeshCrossChainOrder {
    using SafeERC20 for IERC20;

    // State variables
    mapping(bytes32 => CrossChainOrder) public orders;
    mapping(bytes32 => bool) public cancelledOrders;
    mapping(address => uint256) public nonces;

    // Contract dependencies
    IERC20 public immutable weth;
    IMeshLimitOrderProtocol public limitOrderProtocol;
    IMeshEscrow public escrowContract;

    // Enhanced features
    uint256 public constant MIN_ORDER_AMOUNT = 1e15; // 0.001 WETH minimum
    uint256 public constant MAX_ORDER_AMOUNT = 1000e18; // 1000 WETH maximum
    uint256 public constant DEFAULT_TIMELOCK_DURATION = 3600; // 1 hour
    uint256 public constant MAX_TIMELOCK_DURATION = 86400; // 24 hours

    constructor(
        address _weth,
        address _limitOrderProtocol,
        address _escrowContract
    ) {
        weth = IERC20(_weth);
        limitOrderProtocol = IMeshLimitOrderProtocol(_limitOrderProtocol);
        escrowContract = IMeshEscrow(_escrowContract);
    }

    /**
     * @dev Creates a cross-chain order with enhanced features (WETH)
     */
    function createCrossChainOrder(
        uint256 sourceAmount,
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig,
        CrossChainConfig calldata crossChainConfig
    ) external nonReentrant returns (bytes32 orderHash) {
        if (sourceAmount < MIN_ORDER_AMOUNT) revert InvalidSourceAmount();
        if (sourceAmount > MAX_ORDER_AMOUNT) revert ExcessiveSourceAmount();
        if (destinationAmount == 0) revert InvalidDestinationAmount();
        if (crossChainConfig.timelockDuration > MAX_TIMELOCK_DURATION) revert InvalidTimelockDuration();

        // Check WETH allowance
        if (weth.allowance(msg.sender, address(this)) < sourceAmount) {
            revert InsufficientAllowance();
        }

        // Generate order hash
        orderHash = keccak256(
            abi.encodePacked(
                msg.sender,
                sourceAmount,
                destinationAmount,
                auctionConfig.auctionStartTime,
                auctionConfig.auctionEndTime,
                crossChainConfig.suiOrderHash,
                nonces[msg.sender]++,
                block.timestamp,
                block.chainid,
                false // isNativeEth = false for WETH
            )
        );

        if (orders[orderHash].maker != address(0)) revert OrderAlreadyExists();

        // Transfer WETH to contract
        weth.safeTransferFrom(msg.sender, address(this), sourceAmount);

        // Create cross-chain order
        orders[orderHash] = CrossChainOrder({
            maker: msg.sender,
            sourceAmount: sourceAmount,
            destinationAmount: destinationAmount,
            auctionConfig: auctionConfig,
            crossChainConfig: crossChainConfig,
            orderHash: orderHash,
            isActive: true,
            isNativeEth: false, // WETH order
            createdAt: block.timestamp,
            totalFills: 0,
            remainingAmount: sourceAmount
        });

        // Create limit order - convert struct types
        IMeshLimitOrderProtocol.DutchAuctionConfig memory lopConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: auctionConfig.auctionStartTime,
            auctionEndTime: auctionConfig.auctionEndTime,
            startRate: auctionConfig.startRate,
            endRate: auctionConfig.endRate
        });
        
        bytes32 limitOrderHash = limitOrderProtocol.createCrossChainOrder(
            sourceAmount,
            destinationAmount,
            lopConfig
        );

        emit CrossChainOrderCreated(
            orderHash,
            limitOrderHash,
            msg.sender,
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
    }

    /**
     * @dev Creates a cross-chain order with enhanced features (Native ETH)
     */
    function createCrossChainOrderWithEth(
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig,
        CrossChainConfig calldata crossChainConfig
    ) external payable nonReentrant returns (bytes32 orderHash) {
        uint256 sourceAmount = msg.value;
        if (sourceAmount < MIN_ORDER_AMOUNT) revert InvalidSourceAmount();
        if (sourceAmount > MAX_ORDER_AMOUNT) revert ExcessiveSourceAmount();
        if (destinationAmount == 0) revert InvalidDestinationAmount();
        if (crossChainConfig.timelockDuration > MAX_TIMELOCK_DURATION) revert InvalidTimelockDuration();

        // Generate order hash
        orderHash = keccak256(
            abi.encodePacked(
                msg.sender,
                sourceAmount,
                destinationAmount,
                auctionConfig.auctionStartTime,
                auctionConfig.auctionEndTime,
                crossChainConfig.suiOrderHash,
                nonces[msg.sender]++,
                block.timestamp,
                block.chainid,
                true // isNativeEth = true for ETH
            )
        );

        if (orders[orderHash].maker != address(0)) revert OrderAlreadyExists();

        // ETH is already sent with the transaction (msg.value)

        // Create cross-chain order
        orders[orderHash] = CrossChainOrder({
            maker: msg.sender,
            sourceAmount: sourceAmount,
            destinationAmount: destinationAmount,
            auctionConfig: auctionConfig,
            crossChainConfig: crossChainConfig,
            orderHash: orderHash,
            isActive: true,
            isNativeEth: true, // Native ETH order
            createdAt: block.timestamp,
            totalFills: 0,
            remainingAmount: sourceAmount
        });

        // Create limit order - convert struct types
        IMeshLimitOrderProtocol.DutchAuctionConfig memory lopConfig = IMeshLimitOrderProtocol.DutchAuctionConfig({
            auctionStartTime: auctionConfig.auctionStartTime,
            auctionEndTime: auctionConfig.auctionEndTime,
            startRate: auctionConfig.startRate,
            endRate: auctionConfig.endRate
        });
        
        // For native ETH orders, we need to forward the ETH to the limit order protocol
        bytes32 limitOrderHash = limitOrderProtocol.createCrossChainOrderWithEth{value: sourceAmount}(
            destinationAmount,
            lopConfig
        );

        emit CrossChainOrderCreated(
            orderHash,
            limitOrderHash,
            msg.sender,
            sourceAmount,
            destinationAmount,
            auctionConfig,
            crossChainConfig
        );
    }

    /**
     * @dev Fills a cross-chain order with enhanced validation
     */
    function fillCrossChainOrder(
        bytes32 orderHash,
        bytes32 secret,
        uint256 fillAmount,
        string calldata suiTransactionHash
    ) external nonReentrant returns (uint256 filledAmount) {
        CrossChainOrder storage order = orders[orderHash];
        if (order.maker == address(0)) revert OrderNotFound();
        if (!order.isActive) revert OrderNotActive();
        if (cancelledOrders[orderHash]) revert OrderCancelled();
        if (block.timestamp > order.auctionConfig.auctionEndTime) revert OrderExpired();
        if (fillAmount > order.remainingAmount) revert InsufficientRemainingAmount();

        // Validate secret
        bytes32 hashLock = HashLock.generateHashLock(secret);
        if (!HashLock.validateSecret(secret, hashLock)) revert InvalidSecret();

        // Create escrow for this fill based on order type
        uint256 timelock = block.timestamp + order.crossChainConfig.timelockDuration;
        bytes32 escrowId;
        if (order.isNativeEth) {
            // For native ETH orders, create escrow with ETH
            escrowId = escrowContract.createEscrowWithEth{value: fillAmount}(
                hashLock,
                timelock,
                payable(msg.sender),
                order.crossChainConfig.suiOrderHash
            );
        } else {
            // For WETH orders, create escrow with WETH
            escrowId = escrowContract.createEscrow(
                hashLock,
                timelock,
                payable(msg.sender),
                order.crossChainConfig.suiOrderHash,
                fillAmount
            );
        }

        // Update order
        order.totalFills++;
        order.remainingAmount -= fillAmount;
        
        if (order.remainingAmount == 0) {
            order.isActive = false;
        }

        filledAmount = fillAmount;

        emit CrossChainOrderFilled(
            orderHash,
            msg.sender,
            secret,
            fillAmount,
            escrowId,
            suiTransactionHash
        );
    }

    /**
     * @dev Cancels a cross-chain order
     */
    function cancelCrossChainOrder(bytes32 orderHash) external nonReentrant {
        CrossChainOrder storage order = orders[orderHash];
        if (order.maker == address(0)) revert OrderNotFound();
        if (!order.isActive) revert OrderNotActive();
        if (msg.sender != order.maker) revert NotMaker();

        order.isActive = false;
        cancelledOrders[orderHash] = true;

        // Refund remaining funds to maker based on order type
        if (order.remainingAmount > 0) {
            if (order.isNativeEth) {
                // Transfer native ETH
                (bool success, ) = payable(order.maker).call{value: order.remainingAmount}("");
                if (!success) revert TransferFailed();
            } else {
                // Transfer WETH
                weth.safeTransfer(order.maker, order.remainingAmount);
            }
        }

        emit CrossChainOrderCancelled(orderHash, msg.sender);
    }

    /**
     * @dev Gets cross-chain order details
     */
    function getCrossChainOrder(bytes32 orderHash) external view returns (CrossChainOrder memory order) {
        order = orders[orderHash];
    }

    /**
     * @dev Checks if cross-chain order is active
     */
    function isCrossChainOrderActive(bytes32 orderHash) external view returns (bool active) {
        CrossChainOrder storage order = orders[orderHash];
        active = order.isActive && 
                 !cancelledOrders[orderHash] && 
                 block.timestamp <= order.auctionConfig.auctionEndTime;
    }

    /**
     * @dev Gets order statistics
     */
    function getOrderStats(bytes32 orderHash) external view returns (
        uint256 totalFills,
        uint256 remainingAmount,
        uint256 timeRemaining
    ) {
        CrossChainOrder memory order = orders[orderHash];
        totalFills = order.totalFills;
        remainingAmount = order.remainingAmount;
        timeRemaining = TimeLock.timeRemaining(order.auctionConfig.auctionEndTime);
    }

    /**
     * @dev Validates cross-chain configuration
     */
    function validateCrossChainConfig(CrossChainConfig calldata config) external pure returns (bool valid) {
        valid = bytes(config.suiOrderHash).length > 0 &&
                config.timelockDuration > 0 &&
                config.timelockDuration <= MAX_TIMELOCK_DURATION;
    }

    // Enhanced events (events are defined in the interface)

    // Enhanced errors (only non-interface errors)
    // All other errors are defined in the interface
} 