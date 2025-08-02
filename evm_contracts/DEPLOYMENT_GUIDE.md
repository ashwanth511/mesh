# 🚀 Mesh 1inch Fusion+ EVM Contracts - Complete Deployment Guide

## 📋 Overview

This guide covers the complete deployment of Mesh's 1inch Fusion+ cross-chain swap contracts to Ethereum Sepolia testnet and mainnet.

## 🏗️ Architecture

Our implementation includes the complete 1inch Fusion+ stack:

- **MeshEscrow**: HTLC-based escrow for cross-chain atomic swaps
- **MeshLimitOrderProtocol**: Core limit order logic with Dutch auction integration
- **MeshDutchAuction**: Dynamic pricing with bid tracking and statistics
- **MeshResolverNetwork**: Decentralized resolver network with reputation system
- **MeshCrossChainOrder**: Enhanced cross-chain order management

## 🛠️ Prerequisites

### 1. Install Dependencies

```bash
# Install Foundry (if not already installed)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Navigate to contracts directory
cd evm_contracts

# Install dependencies
forge install
```

### 2. Environment Setup

Create a `.env` file in the `evm_contracts` directory:

```bash
# .env file
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_infura_project_id
MAINNET_RPC_URL=https://mainnet.infura.io/v3/your_infura_project_id
```

### 3. Get Test ETH

For Sepolia deployment, get test ETH from:
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Alchemy Sepolia Faucet](https://sepoliafaucet.com/)

## 🧪 Testing

### Run All Tests

```bash
# Run all tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-contract MeshEscrowTest

# Run with verbosity for debugging
forge test -vvv
```

### Expected Test Results

All tests should pass:
- **MeshEscrowTest**: 12 tests (WETH + Native ETH support)
- **MeshDutchAuctionTest**: 15 tests  
- **MeshResolverNetworkTest**: 18 tests
- **MeshLimitOrderProtocolTest**: 17 tests (WETH + Native ETH support)
- **MeshCrossChainOrderTest**: 14 tests (WETH + Native ETH support)

### Test Scripts

#### 1. Comprehensive ETH to SUI Swap Testing

```bash
# Test complete ETH to SUI swap flow (requires deployed contracts)
forge script script/TestETHToSuiSwap.s.sol:TestETHToSuiSwapScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast

# Update contract addresses in script before running:
# MESH_ESCROW = [your_deployed_address]
# MESH_CROSS_CHAIN_ORDER = [your_deployed_address]
# MESH_LIMIT_ORDER_PROTOCOL = [your_deployed_address]
# MESH_DUTCH_AUCTION = [your_deployed_address]
# MESH_RESOLVER_NETWORK = [your_deployed_address]
```

This script tests:
- **Native ETH Cross-Chain Orders**: Direct ETH to SUI swaps
- **WETH Cross-Chain Orders**: WETH to SUI swaps
- **Direct Escrow Creation**: HTLC escrow with native ETH
- **Resolver Network**: Resolver registration and staking

#### 2. Deployment Verification

```bash
# Verify all contracts are deployed correctly
forge script script/VerifyDeployment.s.sol:VerifyDeploymentScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

This script verifies:
- All contracts are deployed
- Contract addresses are valid
- Contract configurations are correct
- WETH and Native ETH support is working

## 🌐 Deployment

### Sepolia Testnet Deployment

```bash
# Build contracts
forge build

# Deploy to Sepolia
forge script script/DeployMesh.s.sol:DeployMesh \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

# Or using cast for individual deployments
cast send --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --create $(forge create src/MeshEscrow.sol:MeshEscrow \
    --constructor-args 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 $YOUR_ADDRESS)
```

### Mainnet Deployment

```bash
# Deploy to Mainnet (use with caution!)
forge script script/DeployMesh.s.sol:DeployMesh \
    --rpc-url $MAINNET_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

## 📋 Contract Addresses

### Sepolia Testnet

After deployment, your contract addresses will be:

```
WETH: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
MeshEscrow: [DEPLOYED_ADDRESS]
MeshDutchAuction: [DEPLOYED_ADDRESS]
MeshResolverNetwork: [DEPLOYED_ADDRESS]
MeshLimitOrderProtocol: [DEPLOYED_ADDRESS]
MeshCrossChainOrder: [DEPLOYED_ADDRESS]
```

### Mainnet

```
WETH: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
MeshEscrow: [DEPLOYED_ADDRESS]
MeshDutchAuction: [DEPLOYED_ADDRESS]
MeshResolverNetwork: [DEPLOYED_ADDRESS]
MeshLimitOrderProtocol: [DEPLOYED_ADDRESS]
MeshCrossChainOrder: [DEPLOYED_ADDRESS]
```

## 🔧 Configuration

### 1. WETH Addresses

- **Sepolia**: `0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9`
- **Mainnet**: `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2`

### 2. Contract Parameters

```solidity
// MeshEscrow
MIN_ESCROW_AMOUNT = 0.001 WETH
MAX_ESCROW_AMOUNT = 1000 WETH
DEFAULT_TIMELOCK = 24 hours

// MeshDutchAuction  
MIN_AUCTION_DURATION = 5 minutes
MAX_AUCTION_DURATION = 24 hours
BID_EXTENSION_WINDOW = 5 minutes

// MeshResolverNetwork
MIN_STAKE = 1 WETH
MAX_STAKE = 100 WETH
MIN_REPUTATION = 0
MAX_REPUTATION = 1000

// MeshLimitOrderProtocol
MIN_ORDER_AMOUNT = 0.001 WETH
MIN_AUCTION_DURATION = 5 minutes
MAX_AUCTION_DURATION = 24 hours
```

## 🎯 Usage Examples

### 1. Create Cross-Chain Order (WETH)

```solidity
// Create order configuration
IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
    auctionStartTime: block.timestamp + 100,
    auctionEndTime: block.timestamp + 3700,
    startRate: 3e18,  // 3 WETH per unit
    endRate: 1e18     // 1 WETH per unit
});

IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
    suiOrderHash: "sui_order_hash",
    timelockDuration: 3600,
    destinationAddress: "0x...",
    secretHash: keccak256("secret")
});

// Approve WETH
IERC20(weth).approve(address(crossChainOrder), sourceAmount);

// Create WETH order
bytes32 orderHash = crossChainOrder.createCrossChainOrder(
    10e18,  // 10 WETH
    20e18,  // 20 SUI tokens
    auctionConfig,
    crossChainConfig
);
```

### 2. Create Cross-Chain Order (Native ETH)

```solidity
// Create order configuration
IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
    auctionStartTime: block.timestamp + 100,
    auctionEndTime: block.timestamp + 3700,
    startRate: 3e18,  // 3 ETH per unit
    endRate: 1e18     // 1 ETH per unit
});

IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
    suiOrderHash: "sui_order_hash",
    timelockDuration: 3600,
    destinationAddress: "0x...",
    secretHash: keccak256("secret")
});

// Create Native ETH order (send ETH with transaction)
bytes32 orderHash = crossChainOrder.createCrossChainOrderWithEth{value: 10e18}(
    20e18,  // 20 SUI tokens
    auctionConfig,
    crossChainConfig
);
```

### 3. Register as Resolver

```solidity
// Approve WETH for staking
IERC20(weth).approve(address(resolverNetwork), stakeAmount);

// Register resolver
resolverNetwork.registerResolver(5e18); // 5 WETH stake
```

### 4. Create Direct Escrow (Native ETH)

```solidity
// Create HTLC escrow with native ETH
bytes32 hashLock = keccak256(abi.encodePacked("secret"));
uint256 timeLock = block.timestamp + 3600; // 1 hour
address payable taker = payable(0x...);

bytes32 escrowId = escrow.createEscrowWithEth{value: 1e18}(
    hashLock,
    timeLock,
    taker,
    "sui_order_hash"
);
```

### 5. Create Direct Escrow (WETH)

```solidity
// Approve WETH
IERC20(weth).approve(address(escrow), amount);

// Create HTLC escrow with WETH
bytes32 hashLock = keccak256(abi.encodePacked("secret"));
uint256 timeLock = block.timestamp + 3600; // 1 hour
address payable taker = payable(0x...);

bytes32 escrowId = escrow.createEscrow(
    hashLock,
    timeLock,
    taker,
    "sui_order_hash",
    amount
);
```

### 6. Fill Order (Resolver)

```solidity
// Fill cross-chain order
uint256 fillAmount = crossChainOrder.fillCrossChainOrder(
    orderHash,
    secret,
    5e18,  // Fill 5 WETH
    "sui_transaction_hash"
);
```

## 🔍 Verification

### Verify Contracts on Etherscan

```bash
# Verify MeshEscrow
forge verify-contract \
    --chain-id 11155111 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address)" 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9 $YOUR_ADDRESS) \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    $MESH_ESCROW_ADDRESS \
    src/MeshEscrow.sol:MeshEscrow

# Verify MeshCrossChainOrder
forge verify-contract \
    --chain-id 11155111 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" $MESH_ESCROW_ADDRESS $MESH_LIMIT_ORDER_PROTOCOL_ADDRESS $MESH_DUTCH_AUCTION_ADDRESS $MESH_RESOLVER_NETWORK_ADDRESS $WETH_ADDRESS) \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    $MESH_CROSS_CHAIN_ORDER_ADDRESS \
    src/core/MeshCrossChainOrder.sol:MeshCrossChainOrder

# Verify other contracts similarly...
```

### Test Without UI

After deployment, test the complete flow:

```bash
# 1. Update contract addresses in TestETHToSuiSwap.s.sol
# 2. Run comprehensive test
forge script script/TestETHToSuiSwap.s.sol:TestETHToSuiSwapScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast

# 3. Verify deployment
forge script script/VerifyDeployment.s.sol:VerifyDeploymentScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## 🚨 Security Considerations

### 1. Private Key Management
- Never commit private keys to git
- Use hardware wallets for mainnet deployments
- Consider using a multisig for contract ownership

### 2. Contract Verification
- Always verify contracts on Etherscan
- Double-check constructor arguments
- Ensure all dependencies are properly linked

### 3. Testing
- Run comprehensive tests before deployment
- Test on testnet extensively
- Use test scripts to verify complete flow
- Consider audit for mainnet deployment

## 🔧 Troubleshooting

### Common Issues

1. **Insufficient Gas**
   ```bash
   # Increase gas limit
   forge script --gas-limit 10000000 ...
   ```

2. **Verification Failed**
   ```bash
   # Check constructor args encoding
   cast abi-encode "constructor(address,address)" 0x... 0x...
   ```

3. **RPC Issues**
   ```bash
   # Try different RPC endpoint
   --rpc-url https://eth-sepolia.g.alchemy.com/v2/your-api-key
   ```

4. **Test Script Contract Addresses**
   ```bash
   # Update addresses in TestETHToSuiSwap.s.sol before running
   # MESH_ESCROW = [deployed_address]
   # MESH_CROSS_CHAIN_ORDER = [deployed_address]
   # etc.
   ```

5. **Compilation Errors**
   ```bash
   # Clean and rebuild
   forge clean
   forge build
   
   # Check for missing dependencies
   forge install
   ```

### Gas Optimization

```bash
# Check gas usage
forge test --gas-report

# Optimize contracts
forge build --optimize --optimizer-runs 200
```

## 📊 Monitoring

### 1. Contract Events

Monitor these key events:
- `EscrowCreated` - New cross-chain swaps
- `CrossChainOrderCreated` - New limit orders
- `ResolverRegistered` - New resolvers joining
- `AuctionInitialized` - Dutch auctions starting

### 2. Metrics to Track

- Total volume processed (WETH + Native ETH)
- Number of active resolvers
- Average auction completion time
- Success rate of cross-chain swaps
- Native ETH vs WETH usage ratio

## 🤝 Integration

### Frontend Integration

```javascript
// Contract ABIs are in out/ directory after compilation
import MeshEscrowABI from './out/MeshEscrow.sol/MeshEscrow.json';
import MeshCrossChainOrderABI from './out/MeshCrossChainOrder.sol/MeshCrossChainOrder.json';

// Initialize contracts
const meshEscrow = new ethers.Contract(MESH_ESCROW_ADDRESS, MeshEscrowABI.abi, signer);
const crossChainOrder = new ethers.Contract(CROSS_CHAIN_ORDER_ADDRESS, MeshCrossChainOrderABI.abi, signer);
```

### API Integration

```javascript
// Listen for events
meshEscrow.on("EscrowCreated", (escrowId, maker, amount, secretHash, timelock, isNativeEth, suiOrderHash) => {
    console.log("New escrow created:", escrowId, "Native ETH:", isNativeEth);
});

crossChainOrder.on("CrossChainOrderCreated", (orderHash, limitOrderHash, maker, sourceAmount, destinationAmount, auctionConfig, crossChainConfig) => {
    console.log("New cross-chain order:", orderHash);
});

// Listen for both WETH and Native ETH orders
crossChainOrder.on("CrossChainOrderFilled", (orderHash, resolver, secret, fillAmount, escrowId, suiTransactionHash) => {
    console.log("Order filled:", orderHash, "Amount:", fillAmount);
});
```

## 📚 Additional Resources

- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [1inch Fusion+ Documentation](https://docs.1inch.io/)
- [Sui Move Documentation](https://docs.sui.io/concepts/sui-move-concepts)

## 🆘 Support

For deployment issues or questions:
1. Check the troubleshooting section above
2. Review test failures for clues
3. Ensure all dependencies are correctly installed
4. Verify environment variables are set correctly

---

**⚠️ Important**: Always test thoroughly on Sepolia before mainnet deployment!