// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IFusionPlus } from "./IFusionPlus.sol";
import { EscrowFactory } from "./EscrowFactory.sol";
import { EscrowSrc } from "./EscrowSrc.sol";

/**
 * @title FusionResolver - Central resolver for cross-chain swaps
 * @notice Coordinates swaps between Ethereum and Sui chains
 * @custom:security-contact security@1inch.io
 */
contract FusionResolver {
    // ===== State Variables =====

    EscrowFactory public immutable escrowFactory;
    mapping(bytes32 => CrossChainSwap) public swaps;
    mapping(address => bool) public authorizedResolvers;
    uint256 public resolverFee;

    // ===== Structs =====

    struct CrossChainSwap {
        bytes32 orderHash;
        address ethereumEscrow;
        address suiEscrow;
        bool isEthereumToSui;
        bool isCompleted;
        bool isCancelled;
        uint256 createdAt;
    }

    // ===== Events =====

    event CrossChainSwapInitiated(
        bytes32 indexed orderHash,
        address indexed maker,
        address indexed taker,
        bool isEthereumToSui
    );

    event CrossChainSwapCompleted(
        bytes32 indexed orderHash,
        address indexed resolver
    );

    event CrossChainSwapCancelled(
        bytes32 indexed orderHash,
        address indexed canceller
    );

    event SuiEscrowSet(
        bytes32 indexed orderHash,
        address suiEscrow
    );

    // ===== Modifiers =====

    modifier onlyAuthorizedResolver() {
        require(authorizedResolvers[msg.sender], "Not authorized resolver");
        _;
    }

    modifier onlyValidSwap(bytes32 orderHash) {
        require(swaps[orderHash].createdAt > 0, "Swap not found");
        _;
    }

    modifier onlyNotCompleted(bytes32 orderHash) {
        require(!swaps[orderHash].isCompleted, "Swap already completed");
        _;
    }

    modifier onlyNotCancelled(bytes32 orderHash) {
        require(!swaps[orderHash].isCancelled, "Swap already cancelled");
        _;
    }

    // ===== Constructor =====

    constructor(address payable _escrowFactory) {
        escrowFactory = EscrowFactory(_escrowFactory);
        authorizedResolvers[msg.sender] = true;
    }

    // ===== Core Functions =====

    /**
     * @notice Initiate Ethereum to Sui swap
     * @param orderConfig The order configuration
     * @param immutables The immutable parameters
     */
    function initiateEthereumToSuiSwap(
        IFusionPlus.OrderConfig memory orderConfig,
        IFusionPlus.Immutables memory immutables
    ) external payable {
        bytes32 orderHash = escrowFactory.computeOrderHash(orderConfig, immutables);
        
        require(swaps[orderHash].createdAt == 0, "Swap already exists");
        require(msg.value >= immutables.safetyDeposit, "Insufficient safety deposit");

        // Create Ethereum escrow
        escrowFactory.createEscrowSrc{value: msg.value}(
            orderConfig,
            immutables
        );

        // Record swap
        swaps[orderHash] = CrossChainSwap({
            orderHash: orderHash,
            ethereumEscrow: escrowFactory.getEscrowSrcAddress(),
            suiEscrow: address(0),
            isEthereumToSui: true,
            isCompleted: false,
            isCancelled: false,
            createdAt: block.timestamp
        });

        emit CrossChainSwapInitiated(orderHash, immutables.maker, immutables.taker, true);
    }

    /**
     * @notice Initiate Sui to Ethereum swap
     * @param orderConfig The order configuration
     * @param immutables The immutable parameters
     */
    function initiateSuiToEthereumSwap(
        IFusionPlus.OrderConfig memory orderConfig,
        IFusionPlus.Immutables memory immutables
    ) external payable {
        bytes32 orderHash = escrowFactory.computeOrderHash(orderConfig, immutables);
        
        require(swaps[orderHash].createdAt == 0, "Swap already exists");
        require(msg.value >= immutables.safetyDeposit, "Insufficient safety deposit");

        // Create Ethereum escrow
        escrowFactory.createEscrowDst{value: msg.value}(
            orderConfig,
            immutables
        );

        // Record swap
        swaps[orderHash] = CrossChainSwap({
            orderHash: orderHash,
            ethereumEscrow: escrowFactory.getEscrowDstAddress(),
            suiEscrow: address(0),
            isEthereumToSui: false,
            isCompleted: false,
            isCancelled: false,
            createdAt: block.timestamp
        });

        emit CrossChainSwapInitiated(orderHash, immutables.maker, immutables.taker, false);
    }

    /**
     * @notice Complete swap by executing withdrawal
     * @param orderHash The hash of the order
     * @param secret The secret that unlocks the escrow
     */
    function completeSwap(
        bytes32 orderHash,
        bytes32 secret
    ) external onlyAuthorizedResolver onlyValidSwap(orderHash) onlyNotCompleted(orderHash) onlyNotCancelled(orderHash) {
        CrossChainSwap storage swap = swaps[orderHash];
        
        // Execute withdrawal on Ethereum side
        EscrowSrc(payable(swap.ethereumEscrow)).withdraw(orderHash, secret);
        
        swap.isCompleted = true;
        
        emit CrossChainSwapCompleted(orderHash, msg.sender);
    }

    /**
     * @notice Cancel swap
     * @param orderHash The hash of the order
     */
    function cancelSwap(
        bytes32 orderHash
    ) external onlyAuthorizedResolver onlyValidSwap(orderHash) onlyNotCompleted(orderHash) onlyNotCancelled(orderHash) {
        CrossChainSwap storage swap = swaps[orderHash];
        
        // Execute cancellation on Ethereum side
        EscrowSrc(payable(swap.ethereumEscrow)).cancel(orderHash);
        
        swap.isCancelled = true;
        
        emit CrossChainSwapCancelled(orderHash, msg.sender);
    }

    /**
     * @notice Set Sui escrow address
     * @param orderHash The hash of the order
     * @param suiEscrow The Sui escrow address
     */
    function setSuiEscrow(
        bytes32 orderHash,
        address suiEscrow
    ) external onlyAuthorizedResolver onlyValidSwap(orderHash) {
        swaps[orderHash].suiEscrow = suiEscrow;
        emit SuiEscrowSet(orderHash, suiEscrow);
    }

    // ===== Admin Functions =====

    /**
     * @notice Add authorized resolver
     * @param resolver The resolver address to add
     */
    function addAuthorizedResolver(address resolver) external {
        require(authorizedResolvers[msg.sender], "Not authorized");
        authorizedResolvers[resolver] = true;
    }

    /**
     * @notice Remove authorized resolver
     * @param resolver The resolver address to remove
     */
    function removeAuthorizedResolver(address resolver) external {
        require(authorizedResolvers[msg.sender], "Not authorized");
        authorizedResolvers[resolver] = false;
    }

    /**
     * @notice Set resolver fee
     * @param fee The new resolver fee
     */
    function setResolverFee(uint256 fee) external {
        require(authorizedResolvers[msg.sender], "Not authorized");
        resolverFee = fee;
    }

    // ===== View Functions =====

    /**
     * @notice Get swap details
     * @param orderHash The hash of the order
     * @return The swap details
     */
    function getSwap(bytes32 orderHash) external view returns (CrossChainSwap memory) {
        return swaps[orderHash];
    }

    /**
     * @notice Check if address is authorized resolver
     * @param resolver The address to check
     * @return True if authorized
     */
    function isAuthorizedResolver(address resolver) external view returns (bool) {
        return authorizedResolvers[resolver];
    }
} 