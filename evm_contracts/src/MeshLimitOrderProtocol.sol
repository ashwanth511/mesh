// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IMeshLimitOrderProtocol} from "./interfaces/IMeshLimitOrderProtocol.sol";
import {IMeshDutchAuction} from "./interfaces/IMeshDutchAuction.sol";
import {IMeshResolverNetwork} from "./interfaces/IMeshResolverNetwork.sol";
import {IMeshEscrow} from "./interfaces/IMeshEscrow.sol";
import {HashLock} from "./utils/HashLock.sol";
import {TimeLock} from "./utils/TimeLock.sol";

/**
 * @title MeshLimitOrderProtocol
 * @dev 1inch Fusion+ Limit Order Protocol implementation for Mesh
 * Integrates Dutch Auction and Resolver Network for competitive price discovery
 * Works with existing HTLC escrow system for cross-chain atomic swaps
 */
contract MeshLimitOrderProtocol is ReentrancyGuard, IMeshLimitOrderProtocol {
    using SafeERC20 for IERC20;

    // State variables
    mapping(bytes32 => LimitOrder) public orders;
    mapping(bytes32 => bool) public cancelledOrders;
    mapping(address => uint256) public nonces;

    // Contract dependencies
    IERC20 public immutable weth;
    IMeshDutchAuction public dutchAuction;
    IMeshResolverNetwork public resolverNetwork;
    IMeshEscrow public escrowContract;

    // Constants
    uint256 public constant MIN_AUCTION_DURATION = 300; // 5 minutes
    uint256 public constant MAX_AUCTION_DURATION = 86400; // 24 hours
    uint256 public constant MIN_ORDER_AMOUNT = 1e15; // 0.001 WETH minimum

    constructor(
        address _weth,
        address _dutchAuction,
        address _resolverNetwork,
        address _escrowContract
    ) {
        weth = IERC20(_weth);
        dutchAuction = IMeshDutchAuction(_dutchAuction);
        resolverNetwork = IMeshResolverNetwork(_resolverNetwork);
        escrowContract = IMeshEscrow(_escrowContract);
    }

    /**
     * @dev Creates a cross-chain limit order with Dutch auction (WETH)
     */
    function createCrossChainOrder(
        uint256 sourceAmount,
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig
    ) external nonReentrant returns (bytes32 orderHash) {
        if (sourceAmount < MIN_ORDER_AMOUNT) revert InvalidSourceAmount();
        if (destinationAmount == 0) revert InvalidDestinationAmount();
        if (auctionConfig.auctionEndTime <= auctionConfig.auctionStartTime) revert InvalidAuctionTimes();
        if (auctionConfig.auctionEndTime - auctionConfig.auctionStartTime < MIN_AUCTION_DURATION) revert AuctionTooShort();
        if (auctionConfig.auctionEndTime - auctionConfig.auctionStartTime > MAX_AUCTION_DURATION) revert AuctionTooLong();
        if (auctionConfig.startRate == 0 || auctionConfig.endRate == 0) revert InvalidRates();

        // Check WETH allowance (allow both user and contract calls)
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
                auctionConfig.startRate,
                auctionConfig.endRate,
                nonces[msg.sender]++,
                block.timestamp,
                block.chainid,
                false // isNativeEth = false for WETH
            )
        );

        if (orders[orderHash].maker != address(0)) revert OrderAlreadyExists();

        // Transfer WETH to contract
        weth.safeTransferFrom(msg.sender, address(this), sourceAmount);

        // Create order
        orders[orderHash] = LimitOrder({
            maker: msg.sender,
            taker: address(0), // Open to any resolver
            sourceAmount: sourceAmount,
            destinationAmount: destinationAmount,
            deadline: auctionConfig.auctionEndTime,
            orderHash: orderHash,
            isActive: true,
            isNativeEth: false, // WETH order
            createdAt: block.timestamp,
            auctionConfig: auctionConfig
        });

        // Initialize Dutch auction
        IMeshDutchAuction.DutchAuctionConfig memory dutchConfig = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: auctionConfig.auctionStartTime,
            auctionEndTime: auctionConfig.auctionEndTime,
            startRate: auctionConfig.startRate,
            endRate: auctionConfig.endRate,
            decreaseRate: 0 // Will be calculated in the auction contract
        });
        dutchAuction.initializeAuction(orderHash, dutchConfig);

        // Register order with resolver network
        resolverNetwork.registerOrder(orderHash, sourceAmount, destinationAmount);

        emit CrossChainOrderCreated(
            orderHash,
            msg.sender,
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
    }

    /**
     * @dev Creates a cross-chain limit order with Dutch auction (Native ETH)
     */
    function createCrossChainOrderWithEth(
        uint256 destinationAmount,
        DutchAuctionConfig calldata auctionConfig
    ) external payable nonReentrant returns (bytes32 orderHash) {
        uint256 sourceAmount = msg.value;
        if (sourceAmount < MIN_ORDER_AMOUNT) revert InvalidSourceAmount();
        if (destinationAmount == 0) revert InvalidDestinationAmount();
        if (auctionConfig.auctionEndTime <= auctionConfig.auctionStartTime) revert InvalidAuctionTimes();
        if (auctionConfig.auctionEndTime - auctionConfig.auctionStartTime < MIN_AUCTION_DURATION) revert AuctionTooShort();
        if (auctionConfig.auctionEndTime - auctionConfig.auctionStartTime > MAX_AUCTION_DURATION) revert AuctionTooLong();
        if (auctionConfig.startRate == 0 || auctionConfig.endRate == 0) revert InvalidRates();

        // Generate order hash
        orderHash = keccak256(
            abi.encodePacked(
                msg.sender,
                sourceAmount,
                destinationAmount,
                auctionConfig.auctionStartTime,
                auctionConfig.auctionEndTime,
                auctionConfig.startRate,
                auctionConfig.endRate,
                nonces[msg.sender]++,
                block.timestamp,
                block.chainid,
                true // isNativeEth = true for ETH
            )
        );

        if (orders[orderHash].maker != address(0)) revert OrderAlreadyExists();

        // ETH is already sent with the transaction (msg.value)

        // Create order
        orders[orderHash] = LimitOrder({
            maker: msg.sender,
            taker: address(0), // Open to any resolver
            sourceAmount: sourceAmount,
            destinationAmount: destinationAmount,
            deadline: auctionConfig.auctionEndTime,
            orderHash: orderHash,
            isActive: true,
            isNativeEth: true, // Native ETH order
            createdAt: block.timestamp,
            auctionConfig: auctionConfig
        });

        // Initialize Dutch auction
        IMeshDutchAuction.DutchAuctionConfig memory dutchConfig = IMeshDutchAuction.DutchAuctionConfig({
            auctionStartTime: auctionConfig.auctionStartTime,
            auctionEndTime: auctionConfig.auctionEndTime,
            startRate: auctionConfig.startRate,
            endRate: auctionConfig.endRate,
            decreaseRate: 0 // Will be calculated in the auction contract
        });
        dutchAuction.initializeAuction(orderHash, dutchConfig);

        // Register order with resolver network
        resolverNetwork.registerOrder(orderHash, sourceAmount, destinationAmount);

        emit CrossChainOrderCreated(
            orderHash,
            msg.sender,
            sourceAmount,
            destinationAmount,
            auctionConfig
        );
    }

    /**
     * @dev Fills a limit order with the correct secret
     */
    function fillLimitOrder(
        bytes32 orderHash,
        bytes32 secret,
        uint256 fillAmount
    ) external nonReentrant returns (uint256 filledAmount) {
        LimitOrder storage order = orders[orderHash];
        if (order.maker == address(0)) revert OrderNotFound();
        if (!order.isActive) revert OrderNotActive();
        if (cancelledOrders[orderHash]) revert OrderAlreadyCancelled();
        if (block.timestamp > order.deadline) revert OrderExpired();

        // Check resolver authorization
        if (!resolverNetwork.isAuthorized(msg.sender)) revert UnauthorizedResolver();

        // Calculate current auction rate
        uint256 currentRate = dutchAuction.calculateCurrentRate(orderHash);
        if (currentRate == 0) revert InvalidRate();

        // Calculate taking amount based on current rate
        uint256 takingAmount = (fillAmount * currentRate) / 1e18;
        if (takingAmount > order.destinationAmount) revert InsufficientDestinationAmount();

        // Create escrow for this fill based on order type
        bytes32 escrowId;
        if (order.isNativeEth) {
            // For native ETH orders, create escrow with ETH
            escrowId = escrowContract.createEscrowWithEth{value: fillAmount}(
                keccak256(abi.encodePacked(secret)),
                order.deadline,
                payable(msg.sender),
                string(abi.encodePacked("order_", orderHash))
            );
        } else {
            // For WETH orders, create escrow with WETH
            escrowId = escrowContract.createEscrow(
                keccak256(abi.encodePacked(secret)),
                order.deadline,
                payable(msg.sender),
                string(abi.encodePacked("order_", orderHash)),
                fillAmount
            );
        }

        // Update order
        order.taker = msg.sender; // Set the resolver as taker
        order.sourceAmount -= fillAmount;
        order.destinationAmount -= takingAmount;
        
        if (order.sourceAmount == 0) {
            order.isActive = false;
        }

        // Transfer funds to resolver based on order type
        if (order.isNativeEth) {
            // Transfer native ETH
            (bool success, ) = payable(msg.sender).call{value: fillAmount}("");
            if (!success) revert TransferFailed();
        } else {
            // Transfer WETH
            weth.safeTransfer(msg.sender, fillAmount);
        }

        // Record fill in resolver network
        resolverNetwork.recordOrderFill(msg.sender, fillAmount, currentRate);

        filledAmount = fillAmount;

        emit LimitOrderFilled(
            orderHash,
            msg.sender,
            secret,
            fillAmount,
            takingAmount,
            currentRate
        );
    }

    /**
     * @dev Cancels an order (only maker can cancel)
     */
    function cancelOrder(bytes32 orderHash) external nonReentrant {
        LimitOrder storage order = orders[orderHash];
        if (order.maker == address(0)) revert OrderNotFound();
        if (!order.isActive) revert OrderNotActive();
        if (msg.sender != order.maker) revert NotMaker();

        order.isActive = false;
        cancelledOrders[orderHash] = true;

        // Refund remaining WETH to maker
        if (order.sourceAmount > 0) {
            weth.safeTransfer(order.maker, order.sourceAmount);
        }

        emit OrderCancelled(orderHash, msg.sender);
    }

    /**
     * @dev Gets order details
     */
    function getOrder(bytes32 orderHash) external view returns (LimitOrder memory order) {
        order = orders[orderHash];
    }

    /**
     * @dev Checks if order exists and is active
     */
    function isOrderActive(bytes32 orderHash) external view returns (bool active) {
        LimitOrder storage order = orders[orderHash];
        active = order.isActive && !cancelledOrders[orderHash] && block.timestamp <= order.deadline;
    }

    /**
     * @dev Gets current auction rate for an order
     */
    function getCurrentRate(bytes32 orderHash) external view returns (uint256 rate) {
        LimitOrder storage order = orders[orderHash];
        if (order.sourceAmount == 0) revert OrderNotFound();
        
        rate = dutchAuction.calculateCurrentRate(orderHash);
    }
} 