# 🚀 Deployment Guide for Sui Fusion+ Integration

## 📋 Prerequisites

1. **Foundry Installation**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Environment Setup**
   ```bash
   cd Contracts/evm contracts
   cp .env.example .env
   ```

3. **Environment Variables** (in `.env`)
   ```env
   PRIVATE_KEY=your_private_key_here
   RPC_URL=https://sepolia.infura.io/v3/your_project_id
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

## 🔧 Configuration

### Step 1: Update Contract Addresses

Edit `script/DeploySui.s.sol` and update these addresses:

```solidity
// For Sepolia Testnet
address public constant ESCROW_FACTORY_ADDRESS = 0x...; // 1inch factory address
address public constant ACCESS_TOKEN_ADDRESS = 0x...;   // Access token address  
address public constant RELAYER_ADDRESS = 0x...;        // Your relayer address
```

### Step 2: Get 1inch Contract Addresses

For Sepolia testnet, you can find the official 1inch addresses:
- **Escrow Factory**: Check 1inch documentation or deploy your own
- **Access Token**: Usually a simple ERC20 token for access control

## 🚀 Deployment Steps

### Step 1: Build Contracts
```bash
forge build
```

### Step 2: Deploy to Testnet
```bash
# Deploy to Sepolia
forge script DeploySui --rpc-url $RPC_URL --broadcast --verify

# Or for local testing
forge script DeploySui --rpc-url http://localhost:8545 --broadcast
```

### Step 3: Verify Deployment
```bash
# Check deployment status
forge script DeploySui --rpc-url $RPC_URL --dry-run
```

## 🧪 Testing

### Run All Tests
```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test file
forge test --match-contract CompleteSwapTest

# Run specific test function
forge test --match-test testEthToSuiSwapComplete
```

### Test Coverage
```bash
# Generate coverage report
forge coverage

# Generate detailed coverage
forge coverage --report lcov
```

## 📊 Test Results

### Expected Test Output
```
Running 15 tests for test/CompleteSwapTest.t.sol:CompleteSwapTest
[PASS] testCancelSwapAfterExpiration() (gas: 123456)
[PASS] testCancelSwapBeforeExpiration() (gas: 123456)
[PASS] testEthToSuiSwapComplete() (gas: 123456)
[PASS] testEthToSuiSwapExpired() (gas: 123456)
[PASS] testEthToSuiSwapInvalidSecret() (gas: 123456)
[PASS] testMinimumAmountValidation() (gas: 123456)
[PASS] testOnlyRelayerCanComplete() (gas: 123456)
[PASS] testSuiToEthSwapComplete() (gas: 123456)
[PASS] testSwapStatusQueries() (gas: 123456)

Running 8 tests for test/SuiResolver.t.sol:SuiResolverTest
[PASS] testArbitraryCallsOnlyOwner() (gas: 123456)
[PASS] testCancelSuiSwap() (gas: 123456)
[PASS] testCancelSuiSwapNotExpired() (gas: 123456)
[PASS] testCancelSuiSwapUnauthorized() (gas: 123456)
[PASS] testCompleteSuiSwap() (gas: 123456)
[PASS] testCompleteSuiSwapInvalidSecret() (gas: 123456)
[PASS] testConstructor() (gas: 123456)
[PASS] testIsSuiSwapActive() (gas: 123456)
[PASS] testRescueETH() (gas: 123456)
[PASS] testRescueETHOnlyOwner() (gas: 123456)
[PASS] testRescueTokens() (gas: 123456)
[PASS] testRescueTokensOnlyOwner() (gas: 123456)
[PASS] testSetRelayer() (gas: 123456)
[PASS] testSetRelayerOnlyOwner() (gas: 123456)

Test result: ok. 24 passed; 0 failed; 0 skipped; finished in 2.34s
```

## 🔍 Manual Testing

### Test 0.003 ETH Swap

1. **Deploy contracts**
   ```bash
   forge script DeploySui --rpc-url $RPC_URL --broadcast
   ```

2. **Start relayer**
   ```bash
   cd ../../relayer
   npm install
   npm run dev
   ```

3. **Test swap flow**
   - Use frontend to initiate 0.003 ETH → SUI swap
   - Monitor relayer logs
   - Verify swap completion

## 🐛 Troubleshooting

### Common Issues

1. **"Source not found" errors**
   ```bash
   # Update remappings
   forge remappings > remappings.txt
   ```

2. **"Stack too deep" errors**
   ```bash
   # Already fixed with via_ir = true in foundry.toml
   ```

3. **Test failures**
   ```bash
   # Check test setup
   forge test --match-test testEthToSuiSwapComplete -vvv
   ```

### Debug Commands

```bash
# Debug specific test
forge test --match-test testEthToSuiSwapComplete -vvvv

# Check gas usage
forge test --gas-report

# Run with specific fork
forge test --fork-url $RPC_URL
```



## 🎯 Demo Preparation

### For Hackathon Demo

1. **Deploy to Sepolia**
   ```bash
   forge script DeploySui --rpc-url $SEPOLIA_RPC --broadcast --verify
   ```

2. **Prepare test accounts**
   - Fund test accounts with ETH
   - Fund test accounts with SUI

3. **Run live demo**
   - Show contract deployment
   - Execute 0.003 ETH → SUI swap
   - Show cross-chain coordination
   - Demonstrate cancellation

### Demo Script
```bash
# 1. Deploy contracts
forge script DeploySui --rpc-url $SEPOLIA_RPC --broadcast

# 2. Start relayer
cd ../../relayer && npm run dev

# 3. Start frontend
cd ../../mes-frontend && npm run dev

# 4. Execute test swap
# Use frontend to swap 0.003 ETH → SUI
```

## 🏆 Success Criteria

- ✅ All 24 tests passing
- ✅ Contracts deployed on testnet
- ✅ 0.003 ETH swap executed successfully
- ✅ Cross-chain coordination working
- ✅ Relayer monitoring events
- ✅ Frontend connected and functional

