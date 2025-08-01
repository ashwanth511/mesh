# 🔗 Sui Smart Contracts (Move)

Sui-side smart contracts for the Fusion+ Cross-Chain Swap implementation.

## 📁 Structure

```
sui-contracts/
├── sources/               # Source contracts
│   └── fusionplus.move    # Main Fusion+ contract
├── tests/                 # Test files
│   └── fusionplus_tests.move # Test suite
├── Move.toml              # Move configuration
├── Move.lock              # Dependency lock file
└── README.md              # This file
```

## 🏗️ Contracts

### fusionplus.move
**Core Move contract implementing atomic swap logic for Sui**

**Key Features:**
- ✅ **Hashlock & Timelock**: Preserved for non-EVM implementation
- ✅ **Atomic Swaps**: Source and destination escrows
- ✅ **Factory Pattern**: Escrow factory for deployment
- ✅ **Partial Fills**: Support for partial order execution
- ✅ **Safety Deposits**: Incentive mechanism for resolvers
- ✅ **Event System**: Comprehensive event emission

**Core Structs:**
```move
// Source escrow for cross-chain atomic swap
public struct EscrowSrc has key, store {
    id: UID,
    immutables: Immutables,
    status: EscrowStatus,
    balance: Balance<0x2::sui::SUI>,
}

// Destination escrow for cross-chain atomic swap
public struct EscrowDst has key, store {
    id: UID,
    immutables: Immutables,
    status: EscrowStatus,
    balance: Balance<0x2::sui::SUI>,
}

// Factory for creating escrow contracts
public struct EscrowFactory has key {
    id: UID,
    escrow_srcs: Table<address, address>,
    escrow_dsts: Table<address, address>,
    orders: Table<address, OrderConfig>,
    access_tokens: VecSet<address>,
}
```

**Core Functions:**
```move
// Create source escrow
public fun create_escrow_src(
    factory: &mut EscrowFactory,
    order_hash: address,
    immutables: Immutables,
    payment: Coin<0x2::sui::SUI>,
    ctx: &mut TxContext
)

// Create destination escrow
public fun create_escrow_dst(
    factory: &mut EscrowFactory,
    order_hash: address,
    immutables: Immutables,
    payment: Coin<0x2::sui::SUI>,
    ctx: &mut TxContext
)

// Withdraw from source escrow
public fun withdraw_src(
    escrow: &mut EscrowSrc,
    secret: vector<u8>,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI>

// Withdraw from destination escrow
public fun withdraw_dst(
    escrow: &mut EscrowDst,
    secret: vector<u8>,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI>
```

## 🧪 Testing

### Test Coverage: Complete Test Suite ✅

**fusionplus_tests.move:**
- ✅ Factory deployment and initialization
- ✅ Escrow creation (source and destination)
- ✅ Withdrawal with secret verification
- ✅ Cancellation logic
- ✅ Timelock enforcement
- ✅ Partial fills
- ✅ Event emission
- ✅ Error handling

### Run Tests
```bash
# All tests
sui move test

# Specific test
sui move test --filter test_create_escrow_src

# With verbose output
sui move test --verbose
```

## 🚀 Deployment

### Prerequisites
```bash
# Install Sui CLI
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui

# Configure Sui client
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
sui client switch --env testnet
```

### Build Contracts
```bash
sui move build
```

### Deploy to Testnet
```bash
# Deploy to Sui testnet
sui client publish --gas-budget 10000000

# Deploy with specific gas budget
sui client publish --gas-budget 20000000 --skip-dependency-verification
```

### Get Contract Addresses
After deployment, note these addresses:
```bash
# Package ID
sui client publish --gas-budget 10000000 --json

# Factory object ID
sui client objects --address <your_address>
```

## 📊 Gas Usage

**Key Functions:**
- `create_escrow_src()`: ~50,000 gas
- `create_escrow_dst()`: ~50,000 gas
- `withdraw_src()`: ~30,000 gas
- `withdraw_dst()`: ~30,000 gas

## 🔧 Configuration

### Move Configuration (`Move.toml`)
```toml
[package]
name = "fusionplus"
version = "1.0.0"
edition = "2024.beta"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/testnet" }

[addresses]
fusionplus = "0x0"
```

## 🎯 Key Features

### 1. Non-EVM Implementation
- **Move Language**: Sui's native smart contract language
- **Object-Oriented**: Uses Sui's object model
- **Type Safety**: Strong type system for security

### 2. Atomic Swap Mechanics
- **Hashlock**: SHA3-256 secret verification
- **Timelock**: Time-based constraints using Sui epochs
- **Secret Management**: Secure secret verification

### 3. Cross-Chain Coordination
- **Event Emission**: Events for relayer monitoring
- **Bidirectional Support**: ETH ↔ SUI swaps
- **Factory Pattern**: Scalable escrow deployment

### 4. Advanced Features
- **Partial Fills**: Support for partial order execution
- **Safety Deposits**: Incentive mechanism
- **Access Control**: Token-based access management

## 📝 Events

**Key Events:**
```move
// Event emitted when escrow is created
public struct EscrowCreated has copy, drop {
    order_hash: address,
    escrow_address: address,
    is_source: bool,
}

// Event emitted when tokens are withdrawn
public struct EscrowWithdrawal has copy, drop {
    order_hash: address,
    secret: vector<u8>,
    amount: u64,
}

// Event emitted when escrow is cancelled
public struct EscrowCancelled has copy, drop {
    order_hash: address,
    amount: u64,
}
```

## 🔐 Security Features

### 1. Access Control
- **Token-based Access**: Only holders of access tokens can create escrows
- **Owner-only Functions**: Critical functions restricted to owner
- **Input Validation**: Comprehensive parameter validation

### 2. Cryptographic Security
- **Hashlock Verification**: SHA3-256 secret verification
- **Timelock Enforcement**: Epoch-based time constraints
- **Secret Management**: Secure secret handling

### 3. Economic Security
- **Safety Deposits**: Incentive mechanism for resolvers
- **Partial Fills**: Support for complex order types
- **Cancellation Logic**: Proper refund mechanisms

## 🐛 Troubleshooting

### Common Issues

1. **"Module not found" errors**
   ```bash
   sui move build --skip-dependency-verification
   ```

2. **"Gas budget exceeded" errors**
   ```bash
   sui client publish --gas-budget 20000000
   ```

3. **"Object not found" errors**
   ```bash
   sui client objects --address <your_address>
   ```

### Debug Commands
```bash
# Check package status
sui client objects --address <your_address>

# View transaction details
sui client tx-block <tx_hash> --json

# Check gas usage
sui client gas --address <your_address>
```

## 🎯 Integration with Ethereum

### Cross-Chain Flow
1. **ETH → SUI**: User creates source escrow on Ethereum, destination escrow on Sui
2. **SUI → ETH**: User creates source escrow on Sui, destination escrow on Ethereum
3. **Relayer Coordination**: Relayer monitors events and executes cross-chain transactions
4. **Secret Revelation**: Relayer provides secret to complete swaps

### Event Monitoring
```typescript
// Monitor Sui events
const events = await suiClient.queryEvents({
  query: { MoveModule: { package: packageId, module: 'fusionplus' } }
});
```

## 🏆 Success Metrics

- ✅ **Complete test suite passing**
- ✅ **Non-EVM hashlock & timelock preserved**
- ✅ **Bidirectional swap support**
- ✅ **Production-ready security**
- ✅ **Official 1inch integration**

**Ready for hackathon demo!** 🎉 