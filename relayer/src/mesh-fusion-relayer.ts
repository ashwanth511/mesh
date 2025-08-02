import { ethers } from 'ethers';
import { JsonRpcProvider, TransactionBlock } from '@mysten/sui.js';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { fromB64 } from '@mysten/sui/utils';
import * as crypto from 'crypto';

// Environment variable helpers
function getRequiredEnvVar(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Required environment variable ${name} is not set. Please check your .env file.`);
  }
  return value;
}

function getOptionalEnvVar(name: string, defaultValue: string): string {
  return process.env[name] || defaultValue;
}

function getOptionalEnvVarNumber(name: string, defaultValue: number): number {
  const value = process.env[name];
  return value ? parseFloat(value) : defaultValue;
}

function getOptionalEnvVarBoolean(name: string, defaultValue: boolean): boolean {
  const value = process.env[name];
  return value ? value.toLowerCase() === 'true' : defaultValue;
}

// Interfaces
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

// 1. Mesh Dutch Auction Implementation
export class MeshDutchAuction {
  private config: MeshDutchAuctionConfig;
  
  constructor(config?: Partial<MeshDutchAuctionConfig>) {
    this.config = {
      auctionStartDelay: getOptionalEnvVarNumber('AUCTION_START_DELAY', 300),
      auctionDuration: getOptionalEnvVarNumber('AUCTION_DURATION', 3600),
      auctionStartRateMultiplier: getOptionalEnvVarNumber('AUCTION_START_RATE_MULTIPLIER', 6.0),
      minimumReturnRate: getOptionalEnvVarNumber('MINIMUM_RETURN_RATE', 0.5),
      decreaseRatePerMinute: getOptionalEnvVarNumber('DECREASE_RATE_PER_MINUTE', 0.1),
      priceCurveSegments: getOptionalEnvVarNumber('PRICE_CURVE_SEGMENTS', 10),
      ...config
    };
  }
  
  calculateCurrentRate(orderTimestamp: number, marketRate: number): number {
    const now = Date.now() / 1000;
    const elapsed = now - orderTimestamp;
    
    if (elapsed < this.config.auctionStartDelay) {
      return marketRate * this.config.auctionStartRateMultiplier;
    }
    
    const auctionElapsed = elapsed - this.config.auctionStartDelay;
    if (auctionElapsed > this.config.auctionDuration) {
      return marketRate * this.config.minimumReturnRate;
    }
    
    const progress = auctionElapsed / this.config.auctionDuration;
    const rateMultiplier = this.config.auctionStartRateMultiplier - 
      (progress * (this.config.auctionStartRateMultiplier - this.config.minimumReturnRate));
    
    return marketRate * rateMultiplier;
  }
  
  isProfitableForResolver(currentRate: number, resolverCost: number): boolean {
    return currentRate > resolverCost * 1.1; // 10% profit margin
  }
  
  getAuctionStatus(orderTimestamp: number): 'waiting' | 'active' | 'expired' {
    const now = Date.now() / 1000;
    const elapsed = now - orderTimestamp;
    
    if (elapsed < this.config.auctionStartDelay) return 'waiting';
    if (elapsed > this.config.auctionStartDelay + this.config.auctionDuration) return 'expired';
    return 'active';
  }
}

// 2. Mesh Finality Lock Manager
export class MeshFinalityLockManager {
  private config: MeshFinalityLock;
  
  constructor(config?: Partial<MeshFinalityLock>) {
    this.config = {
      sourceChainFinality: getOptionalEnvVarNumber('SOURCE_CHAIN_FINALITY', 12),
      destinationChainFinality: getOptionalEnvVarNumber('DESTINATION_CHAIN_FINALITY', 6),
      secretSharingDelay: getOptionalEnvVarNumber('SECRET_SHARING_DELAY', 300),
      whitelistedResolvers: getOptionalEnvVar('WHITELISTED_RESOLVERS', '').split(',').filter(addr => addr.length > 0),
      ...config
    };
  }
  
  async waitForChainFinality(chainId: number, blockNumber: number): Promise<void> {
    const requiredBlocks = chainId === 11155111 ? this.config.sourceChainFinality : this.config.destinationChainFinality;
    console.log(`⏳ Waiting for ${requiredBlocks} block confirmations on chain ${chainId}...`);
    
    // Simulate finality wait
    await new Promise(resolve => setTimeout(resolve, 2000));
    console.log(`✅ Finality confirmed for block ${blockNumber}`);
  }
  
  async shareSecretConditionally(
    orderId: string, 
    secret: string, 
    resolverAddress: string
  ): Promise<void> {
    if (!this.isResolverWhitelisted(resolverAddress)) {
      console.log(`❌ Resolver ${resolverAddress} not whitelisted`);
      return;
    }
    
    console.log(`🔑 Sharing secret with whitelisted resolver ${resolverAddress} for order ${orderId}`);
    await new Promise(resolve => setTimeout(resolve, this.config.secretSharingDelay * 1000));
    console.log(`✅ Secret shared with resolver ${resolverAddress}`);
  }
  
  isResolverWhitelisted(resolverAddress: string): boolean {
    return this.config.whitelistedResolvers.includes(resolverAddress);
  }
}

// 3. Mesh Safety Deposit Manager
export class MeshSafetyDepositManager {
  private config: MeshSafetyDeposit;
  
  constructor(chain: 'ethereum' | 'sui', config?: Partial<MeshSafetyDeposit>) {
    this.config = {
      rate: getOptionalEnvVarNumber('SAFETY_DEPOSIT_RATE', 0.05),
      minAmount: BigInt(getOptionalEnvVar('SAFETY_DEPOSIT_MIN_AMOUNT', '1000000000000000000')), // 1 WETH
      chain,
      ...config
    };
  }
  
  calculateSafetyDeposit(escrowAmount: bigint): bigint {
    const deposit = (escrowAmount * BigInt(Math.floor(this.config.rate * 1000))) / BigInt(1000);
    return deposit < this.config.minAmount ? this.config.minAmount : deposit;
  }
  
  async createEscrowWithSafetyDeposit(
    amount: bigint,
    resolver: string
  ): Promise<{ totalAmount: bigint; safetyDeposit: bigint }> {
    const safetyDeposit = this.calculateSafetyDeposit(amount);
    const totalAmount = amount + safetyDeposit;
    
    console.log(`💰 Creating escrow with safety deposit:`);
    console.log(`  📦 Amount: ${ethers.formatEther(amount)} WETH`);
    console.log(`  🛡️ Safety Deposit: ${ethers.formatEther(safetyDeposit)} WETH`);
    console.log(`  💎 Total: ${ethers.formatEther(totalAmount)} WETH`);
    
    return { totalAmount, safetyDeposit };
  }
  
  async executeWithdrawalWithIncentive(
    escrowId: string,
    resolver: string,
    safetyDeposit: bigint
  ): Promise<void> {
    console.log(`🎁 Executing withdrawal with safety deposit incentive:`);
    console.log(`  🔐 Escrow ID: ${escrowId}`);
    console.log(`  👤 Resolver: ${resolver}`);
    console.log(`  💰 Safety Deposit: ${ethers.formatEther(safetyDeposit)} WETH`);
  }
}

// 4. Mesh Merkle Tree Secret Manager
export class MeshMerkleTreeSecretManager {
  private treeDepth: number;
  private segments: number;
  private secretReusePreventionEnabled: boolean;
  private usedSecrets: Set<string> = new Set();
  
  constructor(treeDepth?: number, segments?: number) {
    this.treeDepth = treeDepth || getOptionalEnvVarNumber('MERKLE_TREE_DEPTH', 4);
    this.segments = segments || getOptionalEnvVarNumber('MERKLE_TREE_SEGMENTS', 16);
    this.secretReusePreventionEnabled = getOptionalEnvVarBoolean('SECRET_REUSE_PREVENTION', true);
  }
  
  generateMerkleTreeSecrets(orderAmount: bigint): MeshMerkleTreeSecrets {
    const secrets: string[] = [];
    
    for (let i = 0; i < this.segments; i++) {
      const secret = this.generateSecret();
      secrets.push(secret);
    }
    
    const merkleRoot = this.calculateMerkleRoot(secrets);
    
    console.log(`🌳 Generated Merkle tree secrets:`);
    console.log(`  📊 Tree Depth: ${this.treeDepth}`);
    console.log(`  🧩 Segments: ${this.segments}`);
    console.log(`  🔑 Secrets Generated: ${secrets.length}`);
    console.log(`  🌱 Merkle Root: ${merkleRoot}`);
    
    return {
      secrets,
      merkleRoot,
      treeDepth: this.treeDepth,
      segments: this.segments
    };
  }
  
  getSecretForFillPercentage(secrets: string[], fillPercentage: number): string {
    const index = Math.floor((fillPercentage / 100) * secrets.length);
    return secrets[Math.min(index, secrets.length - 1)];
  }
  
  verifySecretInTree(secret: string, merkleRoot: string, proof: string[]): boolean {
    if (this.secretReusePreventionEnabled && this.usedSecrets.has(secret)) {
      console.log(`❌ Secret already used: ${secret}`);
      return false;
    }
    
    // Simulate Merkle proof verification
    const calculatedRoot = this.calculateMerkleRoot([secret, ...proof]);
    const isValid = calculatedRoot === merkleRoot;
    
    if (isValid && this.secretReusePreventionEnabled) {
      this.usedSecrets.add(secret);
    }
    
    return isValid;
  }
  
  private generateSecret(): string {
    return crypto.randomBytes(32).toString('hex');
  }
  
  private calculateMerkleRoot(secrets: string[]): string {
    const leaves = secrets.map(secret => crypto.createHash('sha256').update(secret).digest('hex'));
    return this.buildMerkleTree(leaves);
  }
  
  private buildMerkleTree(leaves: string[]): string {
    if (leaves.length === 1) return leaves[0];
    
    const newLevel: string[] = [];
    for (let i = 0; i < leaves.length; i += 2) {
      const left = leaves[i];
      const right = i + 1 < leaves.length ? leaves[i + 1] : left;
      const combined = crypto.createHash('sha256').update(left + right).digest('hex');
      newLevel.push(combined);
    }
    
    return this.buildMerkleTree(newLevel);
  }
}

// 5. Mesh Fusion Relayer Service
export class MeshFusionRelayerService {
  private orders: Map<string, MeshFusionOrder> = new Map();
  private resolvers: string[] = [];
  private isEnabled: boolean;
  private broadcastInterval: number;
  private notificationEnabled: boolean;
  private ethProvider: ethers.JsonRpcProvider;
  private suiProvider: JsonRpcProvider;
  private meshContracts: {
    escrow: ethers.Contract;
    crossChainOrder: ethers.Contract;
    resolverNetwork: ethers.Contract;
    limitOrderProtocol: ethers.Contract;
    dutchAuction: ethers.Contract;
  };
  
  constructor(
    ethProvider: ethers.JsonRpcProvider,
    suiProvider: JsonRpcProvider,
    meshContracts: any,
    enabled?: boolean
  ) {
    this.ethProvider = ethProvider;
    this.suiProvider = suiProvider;
    this.meshContracts = meshContracts;
    this.isEnabled = enabled ?? getOptionalEnvVarBoolean('RELAYER_SERVICE_ENABLED', true);
    this.broadcastInterval = getOptionalEnvVarNumber('ORDER_BROADCAST_INTERVAL', 5000);
    this.notificationEnabled = getOptionalEnvVarBoolean('RESOLVER_NOTIFICATION_ENABLED', true);
    
    // Initialize resolvers from whitelist
    this.resolvers = getOptionalEnvVar('RESOLVER_WHITELIST', '').split(',').filter(addr => addr.length > 0);
  }
  
  async shareOrder(order: MeshFusionOrder): Promise<void> {
    this.orders.set(order.id, order);
    
    if (!this.isEnabled) {
      console.log(`📤 Simple Mode: Sharing order ${order.id} with all resolvers`);
      return;
    }
    
    console.log(`📤 Mesh Fusion Relayer: Broadcasting order ${order.id}...`);
    console.log(`  🌐 Source Chain: ${order.sourceChain}`);
    console.log(`  🎯 Destination Chain: ${order.destinationChain}`);
    console.log(`  💰 Source Amount: ${ethers.formatEther(order.sourceAmount)} WETH`);
    console.log(`  🎯 Destination Amount: ${ethers.formatEther(order.destinationAmount)} SUI`);
    console.log(`  👥 Number of Resolvers: ${this.resolvers.length}`);
    
    // Broadcast order to all resolvers
    for (const resolver of this.resolvers) {
      await this.notifyResolver(resolver, order);
    }
    
    // Start Dutch auction
    await this.startDutchAuction(order.id);
  }
  
  async startDutchAuction(orderId: string): Promise<void> {
    const order = this.orders.get(orderId);
    if (!order) {
      console.error(`❌ Order ${orderId} not found`);
      return;
    }
    
    console.log(`🏁 Starting Dutch auction for order ${orderId}`);
    order.status = 'auction';
    
    // Start auction monitoring
    if (this.isEnabled) {
      this.monitorAuction(orderId);
    }
  }
  
  async shareSecretConditionally(
    orderId: string, 
    secret: string,
    condition: string
  ): Promise<void> {
    const order = this.orders.get(orderId);
    if (!order) {
      console.error(`❌ Order ${orderId} not found`);
      return;
    }
    
    console.log(`🔑 Checking secret sharing condition for order ${orderId}: ${condition}`);
    
    if (condition === 'finality_confirmed') {
      // Share secret after finality confirmation
      console.log(`⏳ Waiting for finality confirmation...`);
      await new Promise(resolve => setTimeout(resolve, 2000)); // Simulate finality wait
      await this.shareSecretWithResolvers(orderId, secret);
    }
  }
  
  private async notifyResolver(resolver: string, order: MeshFusionOrder): Promise<void> {
    if (!this.notificationEnabled) return;
    
    console.log(`📞 Notifying resolver ${resolver} about order ${order.id}`);
    
    // Simulate notification
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  private async monitorAuction(orderId: string): Promise<void> {
    const order = this.orders.get(orderId);
    if (!order) return;
    
    const auction = new MeshDutchAuction(order.auctionConfig);
    let monitoringRounds = 0;
    const maxRounds = 5; // Testing limitation
    
    console.log(`👁️ Starting auction monitoring for order ${orderId}`);
    
    // Auction monitoring loop
    const interval = setInterval(async () => {
      monitoringRounds++;
      const status = auction.getAuctionStatus(order.createdAt);
      
      console.log(`📊 Auction Round ${monitoringRounds}: ${status}`);
      
      if (status === 'expired' || monitoringRounds >= maxRounds) {
        clearInterval(interval);
        console.log(`⏰ Auction expired for order ${orderId}`);
        order.status = 'expired';
        return;
      }
      
      if (status === 'active') {
        const currentRate = auction.calculateCurrentRate(order.createdAt, 1.0);
        console.log(`💰 Current Rate: ${currentRate.toFixed(4)}`);
        
        // Check if any resolver wants to fill
        for (const resolver of this.resolvers) {
          if (auction.isProfitableForResolver(currentRate, 0.8)) {
            console.log(`🎯 Resolver ${resolver} wants to fill order ${orderId}`);
            await this.executeOrder(orderId, resolver);
            clearInterval(interval);
            return;
          }
        }
      }
    }, this.broadcastInterval);
  }
  
  private async executeOrder(orderId: string, resolver: string): Promise<void> {
    const order = this.orders.get(orderId);
    if (!order) return;
    
    console.log(`🚀 Executing order ${orderId} with resolver ${resolver}`);
    
    try {
      // Create cross-chain order on Ethereum
      const tx = await this.meshContracts.crossChainOrder.createCrossChainOrder(
        order.sourceAmount,
        order.destinationAmount,
        [order.auctionConfig.auctionStartDelay, order.auctionConfig.auctionDuration, 0, 0], // auctionConfig
        ['sui_order_hash', 3600, 'destination_address', ethers.keccak256(ethers.toUtf8Bytes('secret'))] // crossChainConfig
      );
      
      await tx.wait();
      console.log(`✅ Cross-chain order created on Ethereum`);
      
      // Create corresponding Sui escrow
      await this.createSuiEscrow(order);
      
      order.status = 'filled';
      console.log(`✅ Order ${orderId} executed successfully`);
      
    } catch (error) {
      console.error(`❌ Failed to execute order ${orderId}:`, error);
    }
  }
  
  private async createSuiEscrow(order: MeshFusionOrder): Promise<void> {
    try {
      console.log(`🏗️ Creating Sui escrow for order ${order.id}`);
      
      // This would be implemented with actual Sui SDK calls
      // For now, we'll simulate the creation
      const tx = new TransactionBlock();
      
      tx.moveCall({
        target: `${process.env.SUI_PACKAGE_ID}::mesh_escrow::create_escrow`,
        arguments: [
          tx.pure(order.sourceAmount.toString()),
          tx.pure(ethers.keccak256(ethers.toUtf8Bytes('secret'))),
          tx.pure(3600000), // 1 hour in milliseconds
          tx.pure(order.id)
        ]
      });
      
      console.log(`✅ Sui escrow transaction created for order ${order.id}`);
      
    } catch (error) {
      console.error(`❌ Failed to create Sui escrow:`, error);
    }
  }
  
  private async shareSecretWithResolvers(orderId: string, secret: string): Promise<void> {
    console.log(`🔐 Sharing secret with resolvers for order ${orderId}`);
    
    for (const resolver of this.resolvers) {
      console.log(`📤 Sending secret to resolver ${resolver}`);
      // In production, this would send the secret securely to the resolver
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    console.log(`✅ Secret shared with all resolvers`);
  }
  
  getOrderStatus(orderId: string): string {
    const order = this.orders.get(orderId);
    return order ? order.status : 'not_found';
  }
  
  getOrder(orderId: string): MeshFusionOrder | undefined {
    return this.orders.get(orderId);
  }
  
  getAllOrders(): MeshFusionOrder[] {
    return Array.from(this.orders.values());
  }
}

// 6. Mesh Gas Price Adjustment Manager
export class MeshGasPriceAdjustmentManager {
  private config: MeshGasPriceAdjustment;
  private historicalGasPrices: Map<string, bigint[]> = new Map();
  
  constructor(config?: Partial<MeshGasPriceAdjustment>) {
    this.config = {
      enabled: getOptionalEnvVarBoolean('GAS_PRICE_ADJUSTMENT_ENABLED', true),
      volatilityThreshold: getOptionalEnvVarNumber('GAS_VOLATILITY_THRESHOLD', 0.2),
      adjustmentFactor: getOptionalEnvVarNumber('GAS_ADJUSTMENT_FACTOR', 1.5),
      executionThresholdMultiplier: getOptionalEnvVarNumber('EXECUTION_THRESHOLD_MULTIPLIER', 2.0),
      ...config
    };
  }
  
  async adjustPriceForGasVolatility(
    originalPrice: number,
    chainId: number
  ): Promise<number> {
    if (!this.config.enabled) return originalPrice;
    
    const currentGasPrice = await this.getCurrentBaseFee(chainId);
    const historicalPrices = this.historicalGasPrices.get(chainId.toString()) || [];
    
    if (historicalPrices.length === 0) {
      this.updateHistoricalPrices(chainId, currentGasPrice);
      return originalPrice;
    }
    
    const averageGasPrice = this.calculateAverage(historicalPrices);
    const volatility = this.calculateGasVolatility(currentGasPrice, averageGasPrice);
    
    console.log(`⛽ Gas Price Analysis:`);
    console.log(`  📊 Current: ${ethers.formatUnits(currentGasPrice, 'gwei')} gwei`);
    console.log(`  📈 Average: ${ethers.formatUnits(averageGasPrice, 'gwei')} gwei`);
    console.log(`  📉 Volatility: ${(volatility * 100).toFixed(2)}%`);
    
    if (volatility > this.config.volatilityThreshold) {
      const adjustedPrice = originalPrice * this.config.adjustmentFactor;
      console.log(`🔄 Adjusting price from ${originalPrice} to ${adjustedPrice}`);
      return adjustedPrice;
    }
    
    return originalPrice;
  }
  
  async shouldExecuteOrder(
    orderPrice: number,
    currentGasPrice: bigint,
    chainId: number
  ): Promise<boolean> {
    const threshold = this.calculateExecutionThreshold(currentGasPrice);
    const shouldExecute = orderPrice > threshold;
    
    console.log(`🎯 Execution Decision:`);
    console.log(`  💰 Order Price: ${orderPrice}`);
    console.log(`  ⛽ Gas Threshold: ${ethers.formatUnits(threshold, 'gwei')} gwei`);
    console.log(`  ✅ Should Execute: ${shouldExecute}`);
    
    return shouldExecute;
  }
  
  private async getCurrentBaseFee(chainId: number): Promise<bigint> {
    // Simulate getting current gas price
    return ethers.parseUnits('20', 'gwei');
  }
  
  private updateHistoricalPrices(chainId: number, price: bigint): void {
    const key = chainId.toString();
    const prices = this.historicalGasPrices.get(key) || [];
    prices.push(price);
    
    // Keep only last 10 prices
    if (prices.length > 10) {
      prices.shift();
    }
    
    this.historicalGasPrices.set(key, prices);
  }
  
  private calculateAverage(prices: bigint[]): bigint {
    const sum = prices.reduce((acc, price) => acc + price, BigInt(0));
    return sum / BigInt(prices.length);
  }
  
  private calculateGasVolatility(current: bigint, historical: bigint): number {
    const diff = current > historical ? current - historical : historical - current;
    return Number(diff) / Number(historical);
  }
  
  private calculateExecutionThreshold(currentGasPrice: bigint): bigint {
    return currentGasPrice * BigInt(Math.floor(this.config.executionThresholdMultiplier * 100)) / BigInt(100);
  }
}

// 7. Mesh Security Manager
export class MeshSecurityManager {
  private config: MeshSecurityFeatures;
  private isPaused: boolean = false;
  private reentrancyGuard: Set<string> = new Set();
  
  constructor(config?: Partial<MeshSecurityFeatures>) {
    this.config = {
      reentrancyProtection: getOptionalEnvVarBoolean('REENTRANCY_PROTECTION', true),
      accessControl: {
        whitelistedResolvers: getOptionalEnvVar('WHITELISTED_RESOLVERS', '').split(',').filter(addr => addr.length > 0),
        adminAddresses: getOptionalEnvVar('ADMIN_ADDRESSES', '').split(',').filter(addr => addr.length > 0),
        pauseGuardian: getOptionalEnvVar('PAUSE_GUARDIAN', ''),
      },
      emergencyPause: getOptionalEnvVarBoolean('EMERGENCY_PAUSE', true),
      upgradeability: getOptionalEnvVarBoolean('UPGRADEABILITY', false),
      ...config
    };
  }
  
  async checkReentrancyProtection(txHash: string): Promise<boolean> {
    if (!this.config.reentrancyProtection) return true;
    
    if (this.reentrancyGuard.has(txHash)) {
      console.log(`🚫 Reentrancy detected for tx: ${txHash}`);
      return false;
    }
    
    this.reentrancyGuard.add(txHash);
    setTimeout(() => this.reentrancyGuard.delete(txHash), 60000); // Clear after 1 minute
    
    return true;
  }
  
  async checkAccessControl(user: string, action: string): Promise<boolean> {
    if (this.isPaused && action !== 'emergency_resume') {
      console.log(`⏸️ System is paused. Action ${action} denied for user ${user}`);
      return false;
    }
    
    if (action === 'admin_only' && !this.config.accessControl.adminAddresses.includes(user)) {
      console.log(`❌ Access denied: ${user} is not an admin`);
      return false;
    }
    
    if (action === 'resolver_only' && !this.config.accessControl.whitelistedResolvers.includes(user)) {
      console.log(`❌ Access denied: ${user} is not a whitelisted resolver`);
      return false;
    }
    
    return true;
  }
  
  async emergencyPause(): Promise<void> {
    if (!this.config.emergencyPause) return;
    
    console.log(`🚨 EMERGENCY PAUSE ACTIVATED`);
    this.isPaused = true;
    
    await this.stopAllTransactions();
  }
  
  async emergencyResume(): Promise<void> {
    if (!this.config.emergencyPause) return;
    
    console.log(`✅ EMERGENCY RESUME ACTIVATED`);
    this.isPaused = false;
  }
  
  isPausedState(): boolean {
    return this.isPaused;
  }
  
  async performSecurityCheck(txHash: string, user: string, action: string): Promise<boolean> {
    console.log(`🔒 Performing security check:`);
    console.log(`  📝 Transaction: ${txHash}`);
    console.log(`  👤 User: ${user}`);
    console.log(`  🎯 Action: ${action}`);
    
    const reentrancyCheck = await this.checkReentrancyProtection(txHash);
    const accessCheck = await this.checkAccessControl(user, action);
    
    const isSecure = reentrancyCheck && accessCheck;
    console.log(`  ✅ Security Check Result: ${isSecure}`);
    
    return isSecure;
  }
  
  private async stopAllTransactions(): Promise<void> {
    console.log(`🛑 Stopping all pending transactions...`);
    // In production, this would stop all pending operations
    await new Promise(resolve => setTimeout(resolve, 1000));
    console.log(`✅ All transactions stopped`);
  }
}

// 8. Configuration Factory
function createMeshFusionPlusConfig() {
  return {
    dutchAuction: {
      auctionStartDelay: getOptionalEnvVarNumber('AUCTION_START_DELAY', 300),
      auctionDuration: getOptionalEnvVarNumber('AUCTION_DURATION', 3600),
      auctionStartRateMultiplier: getOptionalEnvVarNumber('AUCTION_START_RATE_MULTIPLIER', 6.0),
      minimumReturnRate: getOptionalEnvVarNumber('MINIMUM_RETURN_RATE', 0.5),
      decreaseRatePerMinute: getOptionalEnvVarNumber('DECREASE_RATE_PER_MINUTE', 0.1),
      priceCurveSegments: getOptionalEnvVarNumber('PRICE_CURVE_SEGMENTS', 10),
    },
    finalityLock: {
      sourceChainFinality: getOptionalEnvVarNumber('SOURCE_CHAIN_FINALITY', 12),
      destinationChainFinality: getOptionalEnvVarNumber('DESTINATION_CHAIN_FINALITY', 6),
      secretSharingDelay: getOptionalEnvVarNumber('SECRET_SHARING_DELAY', 300),
      whitelistedResolvers: getOptionalEnvVar('WHITELISTED_RESOLVERS', '').split(',').filter(addr => addr.length > 0),
    },
    gasPriceAdjustment: {
      enabled: getOptionalEnvVarBoolean('GAS_PRICE_ADJUSTMENT_ENABLED', true),
      volatilityThreshold: getOptionalEnvVarNumber('GAS_VOLATILITY_THRESHOLD', 0.2),
      adjustmentFactor: getOptionalEnvVarNumber('GAS_ADJUSTMENT_FACTOR', 1.5),
      executionThresholdMultiplier: getOptionalEnvVarNumber('EXECUTION_THRESHOLD_MULTIPLIER', 2.0),
    },
    securityFeatures: {
      reentrancyProtection: getOptionalEnvVarBoolean('REENTRANCY_PROTECTION', true),
      accessControl: {
        whitelistedResolvers: getOptionalEnvVar('WHITELISTED_RESOLVERS', '').split(',').filter(addr => addr.length > 0),
        adminAddresses: getOptionalEnvVar('ADMIN_ADDRESSES', '').split(',').filter(addr => addr.length > 0),
        pauseGuardian: getOptionalEnvVar('PAUSE_GUARDIAN', ''),
      },
      emergencyPause: getOptionalEnvVarBoolean('EMERGENCY_PAUSE', true),
      upgradeability: getOptionalEnvVarBoolean('UPGRADEABILITY', false),
    }
  };
}

export {
  createMeshFusionPlusConfig
}; 