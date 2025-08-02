interface SwapEvent {
    orderHash: string;
    fromChain: 'ethereum' | 'sui';
    toChain: 'ethereum' | 'sui';
    maker: string;
    taker: string;
    amount: string;
    minAmount: string;
    secret: string;
    status: 'pending' | 'created' | 'executed' | 'cancelled';
    createdAt: number;
}
declare class CrossChainRelayer {
    private ethProvider;
    private suiProvider;
    private ethWallet;
    private suiWallet;
    private meshEscrow;
    private meshCrossChainOrder;
    private meshResolverNetwork;
    private meshLimitOrderProtocol;
    private meshDutchAuction;
    private pendingSwaps;
    private isRunning;
    private retryAttempts;
    private maxRetries;
    private healthCheckInterval;
    private lastHealthCheck;
    private fusionRelayer;
    private dutchAuction;
    private finalityLock;
    private safetyDeposit;
    private merkleTree;
    private gasAdjustment;
    private security;
    constructor(ethRpcUrl: string, suiRpcUrl: string, ethPrivateKey: string, suiPrivateKey: string, meshEscrowAddress: string, meshCrossChainOrderAddress: string, meshResolverNetworkAddress: string, meshLimitOrderProtocolAddress: string, meshDutchAuctionAddress: string);
    /**
     * Start the relayer
     */
    start(): Promise<void>;
    /**
     * Stop the relayer
     */
    stop(): void;
    /**
     * Monitor Ethereum events for new swaps
     */
    private monitorEthereumEvents;
    /**
     * Share order with Fusion+ relayer
     */
    private shareOrderWithFusionRelayer;
    /**
     * Monitor Sui events for new swaps
     */
    private monitorSuiEvents;
    /**
     * Create destination escrow on the other chain
     */
    private createDestinationEscrow;
    /**
     * Create Sui destination escrow
     */
    private createSuiDestinationEscrow;
    /**
     * Create Ethereum destination escrow
     */
    private createEthereumDestinationEscrow;
    /**
     * Process pending swaps and execute them when conditions are met
     */
    private processPendingSwaps;
    /**
     * Check if swap is ready for execution
     */
    private isSwapReadyForExecution;
    /**
     * Execute the swap by providing the secret
     */
    private executeSwap;
    /**
     * Generate a deterministic secret for a swap
     */
    private generateSecret;
    /**
     * Get pending swaps
     */
    getPendingSwaps(): SwapEvent[];
    /**
     * Get swap status
     */
    getSwapStatus(orderHash: string): SwapEvent | undefined;
    /**
     * Cancel a swap
     */
    cancelSwap(orderHash: string): Promise<void>;
    private startHealthChecks;
    private performHealthCheck;
    private retryOperation;
}
export interface RelayerConfig {
    ethRpcUrl: string;
    ethPrivateKey: string;
    meshEscrowAddress: string;
    meshCrossChainOrderAddress: string;
    meshResolverNetworkAddress: string;
    meshLimitOrderProtocolAddress: string;
    meshDutchAuctionAddress: string;
    suiRpcUrl: string;
    suiPrivateKey: string;
    suiPackageId: string;
    pollingInterval: number;
}
export declare function startRelayer(config: RelayerConfig): Promise<CrossChainRelayer>;
export { CrossChainRelayer, SwapEvent };
//# sourceMappingURL=relayer.d.ts.map