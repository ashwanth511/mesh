// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IFusionPlus } from "./IFusionPlus.sol";
import { EscrowSrc } from "./EscrowSrc.sol";
import { EscrowDst } from "./EscrowDst.sol";

/**
 * @title EscrowFactory - Factory contract for deploying escrow contracts
 * @notice Manages the deployment and coordination of source and destination escrows
 * @custom:security-contact security@1inch.io
 */
contract EscrowFactory {
    // ===== State Variables =====

    EscrowSrc public immutable escrowSrc;
    EscrowDst public immutable escrowDst;

    // ===== Constructor =====

    constructor() {
        escrowSrc = new EscrowSrc();
        escrowDst = new EscrowDst();
    }

    // ===== Core Functions =====

    /**
     * @notice Create a source escrow
     * @param orderConfig The order configuration
     * @param immutables The immutable parameters
     */
    function createEscrowSrc(
        IFusionPlus.OrderConfig memory orderConfig,
        IFusionPlus.Immutables memory immutables
    ) external payable {
        bytes32 orderHash = computeOrderHash(orderConfig, immutables);
        escrowSrc.createEscrowSrc{value: msg.value}(orderHash, immutables);
    }

    /**
     * @notice Create a destination escrow
     * @param orderConfig The order configuration
     * @param immutables The immutable parameters
     */
    function createEscrowDst(
        IFusionPlus.OrderConfig memory orderConfig,
        IFusionPlus.Immutables memory immutables
    ) external payable {
        bytes32 orderHash = computeOrderHash(orderConfig, immutables);
        escrowDst.createEscrowDst{value: msg.value}(orderHash, immutables);
    }

    // ===== View Functions =====

    /**
     * @notice Get source escrow address
     * @return The source escrow address
     */
    function getEscrowSrcAddress() external view returns (address) {
        return address(escrowSrc);
    }

    /**
     * @notice Get destination escrow address
     * @return The destination escrow address
     */
    function getEscrowDstAddress() external view returns (address) {
        return address(escrowDst);
    }

    /**
     * @notice Check if escrow exists
     * @param orderHash The hash of the order
     * @param isSource Whether it's a source escrow
     * @return True if escrow exists
     */
    function escrowExists(bytes32 orderHash, bool isSource) external view returns (bool) {
        if (isSource) {
            return escrowSrc.getEscrowStatus(orderHash).deployedAt > 0;
        } else {
            return escrowDst.getEscrowStatus(orderHash).deployedAt > 0;
        }
    }

    /**
     * @notice Get order details
     * @param orderHash The hash of the order
     * @param isSource Whether it's a source escrow
     * @return The escrow status and immutables
     */
    function getOrderDetails(
        bytes32 orderHash,
        bool isSource
    ) external view returns (IFusionPlus.EscrowStatus memory, IFusionPlus.Immutables memory) {
        if (isSource) {
            return (
                escrowSrc.getEscrowStatus(orderHash),
                escrowSrc.getEscrowImmutables(orderHash)
            );
        } else {
            return (
                escrowDst.getEscrowStatus(orderHash),
                escrowDst.getEscrowImmutables(orderHash)
            );
        }
    }

    // ===== Helper Functions =====

    /**
     * @notice Compute order hash
     * @param orderConfig The order configuration
     * @param immutables The immutable parameters
     * @return The computed order hash
     */
    function computeOrderHash(
        IFusionPlus.OrderConfig memory orderConfig,
        IFusionPlus.Immutables memory immutables
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                orderConfig.id,
                orderConfig.srcAmount,
                orderConfig.minDstAmount,
                orderConfig.estimatedDstAmount,
                orderConfig.expirationTime,
                orderConfig.srcAssetIsNative,
                orderConfig.dstAssetIsNative,
                immutables.maker,
                immutables.taker,
                immutables.token,
                immutables.amount,
                immutables.hashlock
            )
        );
    }
} 