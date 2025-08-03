# 🔄 Mesh Fusion+ Cross-Chain Relayer



## 🏗️ Architecture

### **Core Components**

**MeshFusionRelayerService:**
- **Dutch Auction Management**: Automated price discovery and bidding
- **Finality Lock Manager**: Cross-chain finality confirmation
- **Safety Deposit Manager**: Incentive-based resolver rewards
- **Merkle Tree Secret Manager**: Advanced secret management
- **Gas Price Adjustment Manager**: Dynamic gas price optimization
- **Security Manager**: Comprehensive security features

**Key Features:**
- ✅ **1inch Fusion+ Integration**: Full Dutch auction and resolver network
- ✅ **Cross-Chain Atomic Swaps**: ETH ↔ SUI with HTLC
- ✅ **Advanced Security**: Reentrancy protection, access control, emergency pause
- ✅ **Gas Optimization**: Dynamic gas price adjustment
- ✅ **Secret Management**: Merkle tree-based secret handling
- ✅ **Health Monitoring**: Comprehensive system health checks
- ✅ **Production Ready**: All features tested and optimized

## 🚀 Quick Start

### Prerequisites
```bash
# Install Node.js (v18+)
node --version

# Install dependencies
npm install
```

### Configuration
```bash
# Copy environment template
cp env.example .env

# Edit environment variables
nano .env
```

### Environment Variables
```env
# Ethereum Configuration
ETH_RPC_URL=https://sepolia.infura.io/v3/your_project_id
ETH_PRIVATE_KEY=your_ethereum_private_key
MESH_ESCROW_ADDRESS=0x... # Deployed MeshEscrow contract address
MESH_CROSS_CHAIN_ORDER_ADDRESS=0x... # Deployed MeshCrossChainOrder contract address
MESH_RESOLVER_NETWORK_ADDRESS=0x... # Deployed MeshResolverNetwork contract address
MESH_LIMIT_ORDER_PROTOCOL_ADDRESS=0x... # Deployed MeshLimitOrderProtocol contract address
MESH_DUTCH_AUCTION_ADDRESS=0x... # Deployed MeshDutchAuction contract address

# Sui Configuration
SUI_RPC_URL=https://fullnode.testnet.sui.io:443
SUI_PRIVATE_KEY=your_sui_private_key
SUI_PACKAGE_ID=0x... # Deployed Sui package ID

# Relayer Configuration
POLLING_INTERVAL=10000

# Fusion+ Configuration
AUCTION_START_DELAY=300
AUCTION_DURATION=3600
AUCTION_START_RATE_MULTIPLIER=6.0
MINIMUM_RETURN_RATE=0.5
DECREASE_RATE_PER_MINUTE=0.1
PRICE_CURVE_SEGMENTS=10
SOURCE_CHAIN_FINALITY=12
DESTINATION_CHAIN_FINALITY=6
SECRET_SHARING_DELAY=300
WHITELISTED_RESOLVERS=0x...,0x...,0x...
ADMIN_ADDRESSES=0x...,0x...
PAUSE_GUARDIAN=0x...
GAS_PRICE_ADJUSTMENT_ENABLED=true
GAS_VOLATILITY_THRESHOLD=0.2
GAS_ADJUSTMENT_FACTOR=1.5
EXECUTION_THRESHOLD_MULTIPLIER=2.0
REENTRANCY_PROTECTION=true
EMERGENCY_PAUSE=true
UPGRADEABILITY=false
```

### Build and Start
```bash
# Build TypeScript
npm run build

# Start relayer
npm start
```

### Expected Output
```
🚀 Starting Mesh Fusion+ Cross-Chain Relayer...
✅ Configuration validated
📡 Connecting to networks...
   Ethereum: https://sepolia.infura.io/v3/...
   Sui: https://fullnode.testnet.sui.io:443
✅ Mesh Fusion+ Relayer started with enhanced features
📊 Monitoring for cross-chain swaps...
🛑 Press Ctrl+C to stop
```

## 🎯 Fusion+ Features

### **1. Dutch Auction System**
```typescript
// Automated price discovery
const auction = new MeshDutchAuction({
  auctionStartDelay: 300,
  auctionDuration: 3600,
  auctionStartRateMultiplier: 6.0,
  minimumReturnRate: 0.5
});

const currentRate = auction.calculateCurrentRate(orderTimestamp, marketRate);
```

### **2. Finality Lock Manager**
```typescript
// Cross-chain finality confirmation
const finalityLock = new MeshFinalityLockManager();
await finalityLock.waitForChainFinality(chainId, blockNumber);
```

### **3. Safety Deposit Manager**
```typescript
// Incentive-based resolver rewards
const safetyDeposit = new MeshSafetyDepositManager('ethereum');
const { totalAmount, safetyDeposit: deposit } = await safetyDeposit.createEscrowWithSafetyDeposit(amount, resolver);
```

### **4. Merkle Tree Secret Manager**
```typescript
// Advanced secret management
const merkleTree = new MeshMerkleTreeSecretManager();
const secrets = merkleTree.generateMerkleTreeSecrets(orderAmount);
```

### **5. Gas Price Adjustment Manager**
```typescript
// Dynamic gas optimization
const gasAdjustment = new MeshGasPriceAdjustmentManager();
const adjustedPrice = await gasAdjustment.adjustPriceForGasVolatility(originalPrice, chainId);
```

### **6. Security Manager**
```typescript
// Comprehensive security
const security = new MeshSecurityManager();
const isSecure = await security.performSecurityCheck(txHash, user, action);
```

## 🔄 Swap Flow

### **ETH → SUI Swap**
1. **Order Creation**: User creates cross-chain order
2. **Dutch Auction**: Automated price discovery starts
3. **Resolver Bidding**: Resolvers compete for best rate
4. **Escrow Creation**: HTLC escrows created on both chains
5. **Secret Sharing**: Secret shared after finality confirmation
6. **Swap Execution**: Atomic swap completed on both chains

### **SUI → ETH Swap**
1. **Order Detection**: Relayer detects Sui escrow creation
2. **Price Calculation**: Current rate calculated via Dutch auction
3. **Resolver Selection**: Best resolver selected based on rate
4. **Cross-Chain Execution**: Atomic swap executed
5. **Funds Transfer**: Funds transferred on both chains

## 🔐 Security Features

### **1. Reentrancy Protection**
- Transaction-level reentrancy guards
- Automatic cleanup after 1 minute
- Comprehensive attack prevention

### **2. Access Control**
- Whitelisted resolver management
- Admin-only functions
- Pause guardian for emergency stops

### **3. Emergency Controls**
- Emergency pause functionality
- Graceful shutdown procedures
- Transaction stopping mechanisms

### **4. Secret Management**
- Merkle tree-based secret generation
- Secret reuse prevention
- Secure secret sharing protocols

## 📊 Monitoring & Analytics

### **Health Checks**
```typescript
// Automatic health monitoring
🏥 Health Check - ETH Block: 1234567, Sui Checkpoint: 987654, Contracts: ✅
```

### **Event Monitoring**
- Cross-chain order creation events
- Dutch auction status updates
- Resolver registration events
- Swap completion events

### **Performance Metrics**
- Order processing time
- Gas price optimization
- Resolver success rates
- Cross-chain finality times


## 🚨 Troubleshooting

### **Common Issues**

**1. Contract Connection Errors**
```bash
# Check contract addresses
cast call $MESH_ESCROW_ADDRESS "weth()" --rpc-url $ETH_RPC_URL

# Verify contract deployment
cast code $MESH_CROSS_CHAIN_ORDER_ADDRESS --rpc-url $ETH_RPC_URL
```

**2. Sui Integration Issues**
   ```bash
# Check Sui package
sui client object $SUI_PACKAGE_ID

# Verify Sui connection
curl https://fullnode.testnet.sui.io:443
```

**3. Gas Price Issues**
   ```bash
# Check current gas price
cast gas-price --rpc-url $ETH_RPC_URL

# Adjust gas settings
export GAS_PRICE_ADJUSTMENT_ENABLED=false
```

**4. Resolver Issues**
```bash
# Check resolver registration
cast call $MESH_RESOLVER_NETWORK_ADDRESS "isAuthorized(address)" $RESOLVER_ADDRESS --rpc-url $ETH_RPC_URL

# Verify resolver stake
cast call $MESH_RESOLVER_NETWORK_ADDRESS "resolvers(address)" $RESOLVER_ADDRESS --rpc-url $ETH_RPC_URL
```

## 🎉 Success Criteria

Your Mesh Fusion+ relayer is ready for production when:

✅ **All contracts deployed and verified**
✅ **Fusion+ components initialized**
✅ **Health checks passing**
✅ **Test swaps completing successfully**
✅ **Security measures active**
✅ **Monitoring configured**
✅ **Emergency procedures tested**


