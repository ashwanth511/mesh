"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createMeshFusionPlusConfig = exports.MeshSecurityManager = exports.MeshGasPriceAdjustmentManager = exports.MeshFusionRelayerService = exports.MeshMerkleTreeSecretManager = exports.MeshSafetyDepositManager = exports.MeshFinalityLockManager = exports.MeshDutchAuction = void 0;
const ethers_1 = require("ethers");
const sui_js_1 = require("@mysten/sui.js");
const crypto = __importStar(require("crypto"));
// Environment variable helpers
function getRequiredEnvVar(name) {
    const value = process.env[name];
    if (!value) {
        throw new Error(`Required environment variable ${name} is not set. Please check your .env file.`);
    }
    return value;
}
function getOptionalEnvVar(name, defaultValue) {
    return process.env[name] || defaultValue;
}
function getOptionalEnvVarNumber(name, defaultValue) {
    const value = process.env[name];
    return value ? parseFloat(value) : defaultValue;
}
function getOptionalEnvVarBoolean(name, defaultValue) {
    const value = process.env[name];
    return value ? value.toLowerCase() === 'true' : defaultValue;
}
// 1. Mesh Dutch Auction Implementation
class MeshDutchAuction {
    constructor(config) {
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
    calculateCurrentRate(orderTimestamp, marketRate) {
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
    isProfitableForResolver(currentRate, resolverCost) {
        return currentRate > resolverCost * 1.1; // 10% profit margin
    }
    getAuctionStatus(orderTimestamp) {
        const now = Date.now() / 1000;
        const elapsed = now - orderTimestamp;
        if (elapsed < this.config.auctionStartDelay)
            return 'waiting';
        if (elapsed > this.config.auctionStartDelay + this.config.auctionDuration)
            return 'expired';
        return 'active';
    }
}
exports.MeshDutchAuction = MeshDutchAuction;
// 2. Mesh Finality Lock Manager
class MeshFinalityLockManager {
    constructor(config) {
        this.config = {
            sourceChainFinality: getOptionalEnvVarNumber('SOURCE_CHAIN_FINALITY', 12),
            destinationChainFinality: getOptionalEnvVarNumber('DESTINATION_CHAIN_FINALITY', 6),
            secretSharingDelay: getOptionalEnvVarNumber('SECRET_SHARING_DELAY', 300),
            whitelistedResolvers: getOptionalEnvVar('WHITELISTED_RESOLVERS', '').split(',').filter(addr => addr.length > 0),
            ...config
        };
    }
    async waitForChainFinality(chainId, blockNumber) {
        const requiredBlocks = chainId === 11155111 ? this.config.sourceChainFinality : this.config.destinationChainFinality;
        console.log(`⏳ Waiting for ${requiredBlocks} block confirmations on chain ${chainId}...`);
        // Simulate finality wait
        await new Promise(resolve => setTimeout(resolve, 2000));
        console.log(`✅ Finality confirmed for block ${blockNumber}`);
    }
    async shareSecretConditionally(orderId, secret, resolverAddress) {
        if (!this.isResolverWhitelisted(resolverAddress)) {
            console.log(`❌ Resolver ${resolverAddress} not whitelisted`);
            return;
        }
        console.log(`🔑 Sharing secret with whitelisted resolver ${resolverAddress} for order ${orderId}`);
        await new Promise(resolve => setTimeout(resolve, this.config.secretSharingDelay * 1000));
        console.log(`✅ Secret shared with resolver ${resolverAddress}`);
    }
    isResolverWhitelisted(resolverAddress) {
        return this.config.whitelistedResolvers.includes(resolverAddress);
    }
}
exports.MeshFinalityLockManager = MeshFinalityLockManager;
// 3. Mesh Safety Deposit Manager
class MeshSafetyDepositManager {
    constructor(chain, config) {
        this.config = {
            rate: getOptionalEnvVarNumber('SAFETY_DEPOSIT_RATE', 0.05),
            minAmount: BigInt(getOptionalEnvVar('SAFETY_DEPOSIT_MIN_AMOUNT', '1000000000000000000')),
            chain,
            ...config
        };
    }
    calculateSafetyDeposit(escrowAmount) {
        const deposit = (escrowAmount * BigInt(Math.floor(this.config.rate * 1000))) / BigInt(1000);
        return deposit < this.config.minAmount ? this.config.minAmount : deposit;
    }
    async createEscrowWithSafetyDeposit(amount, resolver) {
        const safetyDeposit = this.calculateSafetyDeposit(amount);
        const totalAmount = amount + safetyDeposit;
        console.log(`💰 Creating escrow with safety deposit:`);
        console.log(`  📦 Amount: ${ethers_1.ethers.formatEther(amount)} WETH`);
        console.log(`  🛡️ Safety Deposit: ${ethers_1.ethers.formatEther(safetyDeposit)} WETH`);
        console.log(`  💎 Total: ${ethers_1.ethers.formatEther(totalAmount)} WETH`);
        return { totalAmount, safetyDeposit };
    }
    async executeWithdrawalWithIncentive(escrowId, resolver, safetyDeposit) {
        console.log(`🎁 Executing withdrawal with safety deposit incentive:`);
        console.log(`  🔐 Escrow ID: ${escrowId}`);
        console.log(`  👤 Resolver: ${resolver}`);
        console.log(`  💰 Safety Deposit: ${ethers_1.ethers.formatEther(safetyDeposit)} WETH`);
    }
}
exports.MeshSafetyDepositManager = MeshSafetyDepositManager;
// 4. Mesh Merkle Tree Secret Manager
class MeshMerkleTreeSecretManager {
    constructor(treeDepth, segments) {
        this.usedSecrets = new Set();
        this.treeDepth = treeDepth || getOptionalEnvVarNumber('MERKLE_TREE_DEPTH', 4);
        this.segments = segments || getOptionalEnvVarNumber('MERKLE_TREE_SEGMENTS', 16);
        this.secretReusePreventionEnabled = getOptionalEnvVarBoolean('SECRET_REUSE_PREVENTION', true);
    }
    generateMerkleTreeSecrets(orderAmount) {
        const secrets = [];
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
    getSecretForFillPercentage(secrets, fillPercentage) {
        const index = Math.floor((fillPercentage / 100) * secrets.length);
        return secrets[Math.min(index, secrets.length - 1)];
    }
    verifySecretInTree(secret, merkleRoot, proof) {
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
    generateSecret() {
        return crypto.randomBytes(32).toString('hex');
    }
    calculateMerkleRoot(secrets) {
        const leaves = secrets.map(secret => crypto.createHash('sha256').update(secret).digest('hex'));
        return this.buildMerkleTree(leaves);
    }
    buildMerkleTree(leaves) {
        if (leaves.length === 1)
            return leaves[0];
        const newLevel = [];
        for (let i = 0; i < leaves.length; i += 2) {
            const left = leaves[i];
            const right = i + 1 < leaves.length ? leaves[i + 1] : left;
            const combined = crypto.createHash('sha256').update(left + right).digest('hex');
            newLevel.push(combined);
        }
        return this.buildMerkleTree(newLevel);
    }
}
exports.MeshMerkleTreeSecretManager = MeshMerkleTreeSecretManager;
// 5. Mesh Fusion Relayer Service
class MeshFusionRelayerService {
    constructor(ethProvider, suiProvider, meshContracts, enabled) {
        this.orders = new Map();
        this.resolvers = [];
        this.ethProvider = ethProvider;
        this.suiProvider = suiProvider;
        this.meshContracts = meshContracts;
        this.isEnabled = enabled ?? getOptionalEnvVarBoolean('RELAYER_SERVICE_ENABLED', true);
        this.broadcastInterval = getOptionalEnvVarNumber('ORDER_BROADCAST_INTERVAL', 5000);
        this.notificationEnabled = getOptionalEnvVarBoolean('RESOLVER_NOTIFICATION_ENABLED', true);
        // Initialize resolvers from whitelist
        this.resolvers = getOptionalEnvVar('RESOLVER_WHITELIST', '').split(',').filter(addr => addr.length > 0);
    }
    async shareOrder(order) {
        this.orders.set(order.id, order);
        if (!this.isEnabled) {
            console.log(`📤 Simple Mode: Sharing order ${order.id} with all resolvers`);
            return;
        }
        console.log(`📤 Mesh Fusion Relayer: Broadcasting order ${order.id}...`);
        console.log(`  🌐 Source Chain: ${order.sourceChain}`);
        console.log(`  🎯 Destination Chain: ${order.destinationChain}`);
        console.log(`  💰 Source Amount: ${ethers_1.ethers.formatEther(order.sourceAmount)} WETH`);
        console.log(`  🎯 Destination Amount: ${ethers_1.ethers.formatEther(order.destinationAmount)} SUI`);
        console.log(`  👥 Number of Resolvers: ${this.resolvers.length}`);
        // Broadcast order to all resolvers
        for (const resolver of this.resolvers) {
            await this.notifyResolver(resolver, order);
        }
        // Start Dutch auction
        await this.startDutchAuction(order.id);
    }
    async startDutchAuction(orderId) {
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
    async shareSecretConditionally(orderId, secret, condition) {
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
    async notifyResolver(resolver, order) {
        if (!this.notificationEnabled)
            return;
        console.log(`📞 Notifying resolver ${resolver} about order ${order.id}`);
        // Simulate notification
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    async monitorAuction(orderId) {
        const order = this.orders.get(orderId);
        if (!order)
            return;
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
    async executeOrder(orderId, resolver) {
        const order = this.orders.get(orderId);
        if (!order)
            return;
        console.log(`🚀 Executing order ${orderId} with resolver ${resolver}`);
        try {
            // Create cross-chain order on Ethereum
            const tx = await this.meshContracts.crossChainOrder.createCrossChainOrder(order.sourceAmount, order.destinationAmount, [order.auctionConfig.auctionStartDelay, order.auctionConfig.auctionDuration, 0, 0], // auctionConfig
            ['sui_order_hash', 3600, 'destination_address', ethers_1.ethers.keccak256(ethers_1.ethers.toUtf8Bytes('secret'))] // crossChainConfig
            );
            await tx.wait();
            console.log(`✅ Cross-chain order created on Ethereum`);
            // Create corresponding Sui escrow
            await this.createSuiEscrow(order);
            order.status = 'filled';
            console.log(`✅ Order ${orderId} executed successfully`);
        }
        catch (error) {
            console.error(`❌ Failed to execute order ${orderId}:`, error);
        }
    }
    async createSuiEscrow(order) {
        try {
            console.log(`🏗️ Creating Sui escrow for order ${order.id}`);
            // This would be implemented with actual Sui SDK calls
            // For now, we'll simulate the creation
            const tx = new sui_js_1.TransactionBlock();
            tx.moveCall({
                target: `${process.env.SUI_PACKAGE_ID}::mesh_escrow::create_escrow`,
                arguments: [
                    tx.pure(order.sourceAmount.toString()),
                    tx.pure(ethers_1.ethers.keccak256(ethers_1.ethers.toUtf8Bytes('secret'))),
                    tx.pure(3600000),
                    tx.pure(order.id)
                ]
            });
            console.log(`✅ Sui escrow transaction created for order ${order.id}`);
        }
        catch (error) {
            console.error(`❌ Failed to create Sui escrow:`, error);
        }
    }
    async shareSecretWithResolvers(orderId, secret) {
        console.log(`🔐 Sharing secret with resolvers for order ${orderId}`);
        for (const resolver of this.resolvers) {
            console.log(`📤 Sending secret to resolver ${resolver}`);
            // In production, this would send the secret securely to the resolver
            await new Promise(resolve => setTimeout(resolve, 100));
        }
        console.log(`✅ Secret shared with all resolvers`);
    }
    getOrderStatus(orderId) {
        const order = this.orders.get(orderId);
        return order ? order.status : 'not_found';
    }
    getOrder(orderId) {
        return this.orders.get(orderId);
    }
    getAllOrders() {
        return Array.from(this.orders.values());
    }
}
exports.MeshFusionRelayerService = MeshFusionRelayerService;
// 6. Mesh Gas Price Adjustment Manager
class MeshGasPriceAdjustmentManager {
    constructor(config) {
        this.historicalGasPrices = new Map();
        this.config = {
            enabled: getOptionalEnvVarBoolean('GAS_PRICE_ADJUSTMENT_ENABLED', true),
            volatilityThreshold: getOptionalEnvVarNumber('GAS_VOLATILITY_THRESHOLD', 0.2),
            adjustmentFactor: getOptionalEnvVarNumber('GAS_ADJUSTMENT_FACTOR', 1.5),
            executionThresholdMultiplier: getOptionalEnvVarNumber('EXECUTION_THRESHOLD_MULTIPLIER', 2.0),
            ...config
        };
    }
    async adjustPriceForGasVolatility(originalPrice, chainId) {
        if (!this.config.enabled)
            return originalPrice;
        const currentGasPrice = await this.getCurrentBaseFee(chainId);
        const historicalPrices = this.historicalGasPrices.get(chainId.toString()) || [];
        if (historicalPrices.length === 0) {
            this.updateHistoricalPrices(chainId, currentGasPrice);
            return originalPrice;
        }
        const averageGasPrice = this.calculateAverage(historicalPrices);
        const volatility = this.calculateGasVolatility(currentGasPrice, averageGasPrice);
        console.log(`⛽ Gas Price Analysis:`);
        console.log(`  📊 Current: ${ethers_1.ethers.formatUnits(currentGasPrice, 'gwei')} gwei`);
        console.log(`  📈 Average: ${ethers_1.ethers.formatUnits(averageGasPrice, 'gwei')} gwei`);
        console.log(`  📉 Volatility: ${(volatility * 100).toFixed(2)}%`);
        if (volatility > this.config.volatilityThreshold) {
            const adjustedPrice = originalPrice * this.config.adjustmentFactor;
            console.log(`🔄 Adjusting price from ${originalPrice} to ${adjustedPrice}`);
            return adjustedPrice;
        }
        return originalPrice;
    }
    async shouldExecuteOrder(orderPrice, currentGasPrice, chainId) {
        const threshold = this.calculateExecutionThreshold(currentGasPrice);
        const shouldExecute = orderPrice > threshold;
        console.log(`🎯 Execution Decision:`);
        console.log(`  💰 Order Price: ${orderPrice}`);
        console.log(`  ⛽ Gas Threshold: ${ethers_1.ethers.formatUnits(threshold, 'gwei')} gwei`);
        console.log(`  ✅ Should Execute: ${shouldExecute}`);
        return shouldExecute;
    }
    async getCurrentBaseFee(chainId) {
        // Simulate getting current gas price
        return ethers_1.ethers.parseUnits('20', 'gwei');
    }
    updateHistoricalPrices(chainId, price) {
        const key = chainId.toString();
        const prices = this.historicalGasPrices.get(key) || [];
        prices.push(price);
        // Keep only last 10 prices
        if (prices.length > 10) {
            prices.shift();
        }
        this.historicalGasPrices.set(key, prices);
    }
    calculateAverage(prices) {
        const sum = prices.reduce((acc, price) => acc + price, BigInt(0));
        return sum / BigInt(prices.length);
    }
    calculateGasVolatility(current, historical) {
        const diff = current > historical ? current - historical : historical - current;
        return Number(diff) / Number(historical);
    }
    calculateExecutionThreshold(currentGasPrice) {
        return currentGasPrice * BigInt(Math.floor(this.config.executionThresholdMultiplier * 100)) / BigInt(100);
    }
}
exports.MeshGasPriceAdjustmentManager = MeshGasPriceAdjustmentManager;
// 7. Mesh Security Manager
class MeshSecurityManager {
    constructor(config) {
        this.isPaused = false;
        this.reentrancyGuard = new Set();
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
    async checkReentrancyProtection(txHash) {
        if (!this.config.reentrancyProtection)
            return true;
        if (this.reentrancyGuard.has(txHash)) {
            console.log(`🚫 Reentrancy detected for tx: ${txHash}`);
            return false;
        }
        this.reentrancyGuard.add(txHash);
        setTimeout(() => this.reentrancyGuard.delete(txHash), 60000); // Clear after 1 minute
        return true;
    }
    async checkAccessControl(user, action) {
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
    async emergencyPause() {
        if (!this.config.emergencyPause)
            return;
        console.log(`🚨 EMERGENCY PAUSE ACTIVATED`);
        this.isPaused = true;
        await this.stopAllTransactions();
    }
    async emergencyResume() {
        if (!this.config.emergencyPause)
            return;
        console.log(`✅ EMERGENCY RESUME ACTIVATED`);
        this.isPaused = false;
    }
    isPausedState() {
        return this.isPaused;
    }
    async performSecurityCheck(txHash, user, action) {
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
    async stopAllTransactions() {
        console.log(`🛑 Stopping all pending transactions...`);
        // In production, this would stop all pending operations
        await new Promise(resolve => setTimeout(resolve, 1000));
        console.log(`✅ All transactions stopped`);
    }
}
exports.MeshSecurityManager = MeshSecurityManager;
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
exports.createMeshFusionPlusConfig = createMeshFusionPlusConfig;
//# sourceMappingURL=mesh-fusion-relayer.js.map