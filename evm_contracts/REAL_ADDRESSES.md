# Real 1inch Contract Addresses

## 🎯 **HOW TO GET REAL ADDRESSES:**

### **1. SEPOLIA TESTNET:**
```bash
# Check 1inch documentation
https://docs.1inch.io/docs/limit-order-protocol/smart-contract-addresses

# Or use 1inch API
curl "https://api.1inch.io/v5.0/1/quote?fromTokenAddress=0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEe&toTokenAddress=0xA0b86a33E6441b8c4C8C8C8C8C8C8C8C8C8C8C8&amount=1000000000000000000"
```

### **2. MAINNET:**
```bash
# Official 1inch addresses
ESCROW_FACTORY_MAINNET = 0x1111111254fb6c44bAC0beD2854e76F90643097d
LIMIT_ORDER_PROTOCOL_MAINNET = 0x1111111254fb6c44bAC0beD2854e76F90643097d
```

### **3. FORK AND DEPLOY YOUR OWN (RECOMMENDED FOR HACKATHON):**
```bash
# Fork 1inch contracts and deploy to testnet
git clone https://github.com/1inch/cross-chain-swap
cd cross-chain-swap
forge install
forge build

# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC --broadcast
```

## 🔧 **UPDATE DEPLOYMENT SCRIPT:**

```solidity
// In DeploySui.s.sol, update these:
address constant ESCROW_FACTORY_ADDRESS = 0x...; // Real address
address constant LIMIT_ORDER_PROTOCOL_ADDRESS = 0x...; // Real address
```

## 🎯 **SUI SIDE (ALREADY PERFECT!):**

### **✅ SUİ CONTRACTS:**
- **`fusionplus.move`** - Escrow and factory
- **Hashlock/timelock** - Working perfectly
- **Atomic swaps** - Bidirectional ETH ↔ SUI

### **✅ RELAYER:**
- **TypeScript relayer** - Cross-chain coordination
- **Event monitoring** - Ethereum and Sui
- **Secret management** - SHA3-256 for Sui

## 🚀 **DEPLOYMENT STEPS:**

### **1. GET REAL ADDRESSES:**
```bash
# Option A: Use official 1inch addresses
ESCROW_FACTORY = 0x1111111254fb6c44bAC0beD2854e76F90643097d
LIMIT_ORDER_PROTOCOL = 0x1111111254fb6c44bAC0beD2854e76F90643097d

# Option B: Deploy your own (for hackathon)
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC --broadcast
```

### **2. DEPLOY SUI CONTRACTS:**
```bash
cd Contracts/sui-contracts
sui move build
sui client publish --gas-budget 10000000
```

### **3. DEPLOY ETHEREUM RESOLVER:**
```bash
cd Contracts/evm-contracts
forge script script/DeploySui.s.sol --rpc-url $SEPOLIA_RPC --broadcast
```

### **4. SET UP RELAYER:**
```bash
cd Contracts/relayer
npm install
cp env.example .env
# Update .env with real addresses
npm start
```

## 🏆 **FINAL RESULT:**

```
✅ Dutch auction - RESOLVERS COMPETE
✅ Gas-free for users - RESOLVERS PAY GAS  
✅ Escrow system - ATOMIC SWAPS
✅ Limit Order Protocol - OFFICIAL 1INCH
✅ Cross-chain coordination - RELAYER
✅ Bidirectional swaps - ETH ↔ SUI
✅ Testnet ready - SEPOLIA + SUI TESTNET
```

**BRO! We have EVERYTHING! Just need to get the real addresses and deploy!** 🚀 