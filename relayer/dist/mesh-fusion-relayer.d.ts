import { ethers } from 'ethers';
import { JsonRpcProvider } from '@mysten/sui.js';
export interface MeshDutchAuctionConfig {
    auctionStartDelay: number;
    auctionDuration: number;
    auctionStartRateMultiplier: number;
    minimumReturnRate: number;
    decreaseRatePerMinute: number;
    priceCurveSegments: number;
}
export interface MeshFinalityLock {
    sourceChainFinality: number;
    destinationChainFinality: number;
    secretSharingDelay: number;
    whitelistedResolvers: string[];
}
export interface MeshSafetyDeposit {
    rate: number;
    minAmount: bigint;
    chain: 'ethereum' | 'sui';
}
export interface MeshMerkleTreeSecrets {
    secrets: string[];
    merkleRoot: string;
    treeDepth: number;
    segments: number;
}
export interface MeshFusionOrder {
    id: string;
    maker: string;
    sourceChain: string;
    destinationChain: string;
    sourceAmount: bigint;
    destinationAmount: bigint;
    auctionConfig: MeshDutchAuctionConfig;
    createdAt: number;
    status: 'pending' | 'auction' | 'filled' | 'expired';
    merkleRoot?: string;
    safetyDeposit?: bigint;
    escrowId?: string;
    secret?: string;
}
export interface MeshGasPriceAdjustment {
    enabled: boolean;
    volatilityThreshold: number;
    adjustmentFactor: number;
    executionThresholdMultiplier: number;
}
export interface MeshAccessControl {
    whitelistedResolvers: string[];
    adminAddresses: string[];
    pauseGuardian: string;
}
export interface MeshSecurityFeatures {
    reentrancyProtection: boolean;
    accessControl: MeshAccessControl;
    emergencyPause: boolean;
    upgradeability: boolean;
}
export declare class MeshDutchAuction {
    private config;
    constructor(config?: Partial<MeshDutchAuctionConfig>);
    calculateCurrentRate(orderTimestamp: number, marketRate: number): number;
    isProfitableForResolver(currentRate: number, resolverCost: number): boolean;
    getAuctionStatus(orderTimestamp: number): 'waiting' | 'active' | 'expired';
}
export declare class MeshFinalityLockManager {
    private config;
    constructor(config?: Partial<MeshFinalityLock>);
    waitForChainFinality(chainId: number, blockNumber: number): Promise<void>;
    shareSecretConditionally(orderId: string, secret: string, resolverAddress: string): Promise<void>;
    isResolverWhitelisted(resolverAddress: string): boolean;
}
export declare class MeshSafetyDepositManager {
    private config;
    constructor(chain: 'ethereum' | 'sui', config?: Partial<MeshSafetyDeposit>);
    calculateSafetyDeposit(escrowAmount: bigint): bigint;
    createEscrowWithSafetyDeposit(amount: bigint, resolver: string): Promise<{
        totalAmount: bigint;
        safetyDeposit: bigint;
    }>;
    executeWithdrawalWithIncentive(escrowId: string, resolver: string, safetyDeposit: bigint): Promise<void>;
}
export declare class MeshMerkleTreeSecretManager {
    private treeDepth;
    private segments;
    private secretReusePreventionEnabled;
    private usedSecrets;
    constructor(treeDepth?: number, segments?: number);
    generateMerkleTreeSecrets(orderAmount: bigint): MeshMerkleTreeSecrets;
    getSecretForFillPercentage(secrets: string[], fillPercentage: number): string;
    verifySecretInTree(secret: string, merkleRoot: string, proof: string[]): boolean;
    private generateSecret;
    private calculateMerkleRoot;
    private buildMerkleTree;
}
export declare class MeshFusionRelayerService {
    private orders;
    private resolvers;
    private isEnabled;
    private broadcastInterval;
    private notificationEnabled;
    private ethProvider;
    private suiProvider;
    private meshContracts;
    constructor(ethProvider: ethers.JsonRpcProvider, suiProvider: JsonRpcProvider, meshContracts: any, enabled?: boolean);
    shareOrder(order: MeshFusionOrder): Promise<void>;
    startDutchAuction(orderId: string): Promise<void>;
    shareSecretConditionally(orderId: string, secret: string, condition: string): Promise<void>;
    private notifyResolver;
    private monitorAuction;
    private executeOrder;
    private createSuiEscrow;
    private shareSecretWithResolvers;
    getOrderStatus(orderId: string): string;
    getOrder(orderId: string): MeshFusionOrder | undefined;
    getAllOrders(): MeshFusionOrder[];
}
export declare class MeshGasPriceAdjustmentManager {
    private config;
    private historicalGasPrices;
    constructor(config?: Partial<MeshGasPriceAdjustment>);
    adjustPriceForGasVolatility(originalPrice: number, chainId: number): Promise<number>;
    shouldExecuteOrder(orderPrice: number, currentGasPrice: bigint, chainId: number): Promise<boolean>;
    private getCurrentBaseFee;
    private updateHistoricalPrices;
    private calculateAverage;
    private calculateGasVolatility;
    private calculateExecutionThreshold;
}
export declare class MeshSecurityManager {
    private config;
    private isPaused;
    private reentrancyGuard;
    constructor(config?: Partial<MeshSecurityFeatures>);
    checkReentrancyProtection(txHash: string): Promise<boolean>;
    checkAccessControl(user: string, action: string): Promise<boolean>;
    emergencyPause(): Promise<void>;
    emergencyResume(): Promise<void>;
    isPausedState(): boolean;
    performSecurityCheck(txHash: string, user: string, action: string): Promise<boolean>;
    private stopAllTransactions;
}
declare function createMeshFusionPlusConfig(): {
    dutchAuction: {
        auctionStartDelay: number;
        auctionDuration: number;
        auctionStartRateMultiplier: number;
        minimumReturnRate: number;
        decreaseRatePerMinute: number;
        priceCurveSegments: number;
    };
    finalityLock: {
        sourceChainFinality: number;
        destinationChainFinality: number;
        secretSharingDelay: number;
        whitelistedResolvers: string[];
    };
    gasPriceAdjustment: {
        enabled: boolean;
        volatilityThreshold: number;
        adjustmentFactor: number;
        executionThresholdMultiplier: number;
    };
    securityFeatures: {
        reentrancyProtection: boolean;
        accessControl: {
            whitelistedResolvers: string[];
            adminAddresses: string[];
            pauseGuardian: string;
        };
        emergencyPause: boolean;
        upgradeability: boolean;
    };
};
export { createMeshFusionPlusConfig };
//# sourceMappingURL=mesh-fusion-relayer.d.ts.map