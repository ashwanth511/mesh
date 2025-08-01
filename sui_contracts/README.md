# Mesh Cross-Chain Escrow System (Sui)

A complete cross-chain atomic swap system for Sui to Ethereum swaps and vice versa, implementing the Hash-Time Lock Contract (HTLC) pattern.

## Overview

This system enables secure atomic swaps between Sui and Ethereum chains using cryptographic primitives and time-based locks. The implementation includes:

- **Hash-Time Lock Contracts (HTLC)**: Secure atomic swap mechanism
- **Partial Fill Support**: Allow escrows to be filled in multiple transactions
- **Secret Reuse Prevention**: Global registry to prevent secret reuse across escrows
- **Time-based Expiration**: Automatic refund mechanism after timeout
- **Factory Pattern**: Centralized management of escrow contracts
- **Access Control**: Role-based permissions for administrative functions

## Architecture

### Core Modules

1. **`mesh_escrow.move`** - Main escrow contract with HTLC functionality
2. **`mesh_hash_lock.move`** - Utility module for hash lock operations
3. **`mesh_time_lock.move`** - Utility module for time lock operations

### Key Components

#### CrossChainEscrow
- Generic escrow contract supporting any coin type
- Maker/Taker roles with optional open fills
- Partial fill support with remaining amount tracking
- Automatic secret storage after first fill
- Comprehensive state management

#### UsedSecretsRegistry
- Global registry to prevent secret reuse across escrows
- Maintains list of all used secrets
- Prevents double-spending attacks

#### EscrowFactory
- Centralized factory for managing escrows
- Access token management
- Escrow tracking and statistics

## Features

### ✅ Implemented Features

1. **Complete HTLC Pattern**
   - Hash lock creation and verification
   - Time lock validation and expiration
   - Secret revelation and validation

2. **Security Features**
   - Reentrancy protection
   - Secret reuse prevention
   - Access control mechanisms
   - Comprehensive error handling

3. **Flexible Escrow Management**
   - Partial fills support
   - Multiple coin type support
   - Factory pattern for scalability
   - Event emission for tracking

4. **Time-based Operations**
   - Precise time lock validation using Sui Clock
   - Automatic expiration handling
   - Refund mechanism after timeout

5. **Utility Functions**
   - Hash lock utilities (create, verify, validate)
   - Time lock utilities (create, validate, check expiration)
   - Batch operations for testing

### 🔧 Key Improvements Over Reference

1. **Modular Design**: Separate utility modules for better code organization
2. **Enhanced Security**: Global secret reuse prevention
3. **Better Testing**: Comprehensive test suite with multiple scenarios
4. **Factory Pattern**: Centralized escrow management
5. **Event System**: Complete event emission for tracking
6. **Access Control**: Role-based permissions
7. **Unique Module Names**: No conflicts with reference implementation

## Usage

### Creating an Escrow

```move
// Create secret and hash lock
let secret = mesh_hash_lock::generate_test_secret(123);
let hash_lock = mesh_hash_lock::create_hash_lock(secret);

// Create time lock
let time_lock = mesh_time_lock::create_time_lock(mesh_time_lock::standard_duration(), &clock);

// Create escrow
let escrow = mesh_escrow::create_escrow(
    coin,
    taker_address,
    hash_lock,
    time_lock,
    ethereum_order_hash,
    &clock,
    ctx
);
```

### Filling an Escrow

```move
// Fill escrow completely
let filled_coin = mesh_escrow::fill_escrow(
    &mut escrow,
    &mut registry,
    secret,
    &clock,
    ctx
);

// Or fill partially
let partial_coin = mesh_escrow::fill_escrow_partial(
    &mut escrow,
    &mut registry,
    amount,
    secret,
    &clock,
    ctx
);
```

### Cancelling an Expired Escrow

```move
// Cancel after timeout
let refunded_coin = mesh_escrow::cancel_escrow(
    &mut escrow,
    &clock,
    ctx
);
```

## Testing

The system includes comprehensive tests covering:

- Escrow creation and validation
- Complete and partial fills
- Cancellation mechanisms
- Secret reuse prevention
- Utility functions
- Factory operations

Run tests with:
```bash
sui move test
```

## Security Considerations

1. **Secret Management**: Secrets are stored after first use to prevent reuse
2. **Time Validation**: Uses Sui's Clock for precise time operations
3. **Access Control**: Role-based permissions for administrative functions
4. **Error Handling**: Comprehensive error codes and validation
5. **Reentrancy Protection**: Built-in protection against reentrancy attacks

## Cross-Chain Integration

This Sui implementation works seamlessly with the Ethereum contracts in the `evm_contracts/` directory:

1. **Shared Secrets**: Same hash lock mechanism on both chains
2. **Coordinated Timelocks**: Synchronized time-based operations
3. **Event Tracking**: Events for cross-chain order tracking
4. **Atomic Swaps**: Complete atomic swap flow between chains

## Deployment

1. Build the contracts:
```bash
sui move build
```

2. Deploy to Sui network:
```bash
sui client publish --gas-budget 10000000
```

3. Initialize the system:
```move
mesh_escrow::init(ctx)
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Support

For questions and support, please open an issue in the repository. 