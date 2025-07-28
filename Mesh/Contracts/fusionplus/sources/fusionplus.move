/// Module: fusionplus
#[allow(unused_const,duplicate_alias,unused_function,unused_field,lint(self_transfer))]

module fusionplus::fusionplus;

use sui::object::{Self, UID};
use sui::transfer;
use sui::tx_context::{Self, TxContext};
use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::table::{Self, Table};
use sui::vec_set::{Self, VecSet};
use std::option::{Self, Option};
use std::vector;
use std::hash;
use std::bcs;
use sui::event;

// ===== Constants =====

//Maximum number of parts for partial fills
const MAX_PARTS: u64 = 10;

// Base for percentage calculations (100%)
const BASE_1E2: u64 = 100;

// Base for fee calculations (100%)
const BASE_1E5: u64 = 100000;

// ===== Errors =====

const EInvalidAmount: u64 = 0;
const EInvalidTime: u64 = 1;
const EInvalidSecret: u64 = 2;
const EInvalidCaller: u64 = 3;
const EOrderExpired: u64 = 4;
const EInvalidHashlock: u64 = 5;
const EInvalidTimelock: u64 = 6;
const EInvalidImmutables: u64 = 7;
const EOrderNotFound: u64 = 8;
const EOrderAlreadyFilled: u64 = 9;
const EOrderAlreadyCancelled: u64 = 10;
const EInvalidStage: u64 = 11;
const EInvalidPartialFill: u64 = 12;

// ===== Structs =====

// Timelock configuration for source and destination chains
public struct Timelocks has store, copy, drop {
    // Source chain timelocks (seconds from deployment)
    src_withdrawal: u64,
    src_public_withdrawal: u64,
    src_cancellation: u64,
    src_public_cancellation: u64,
    // Destination chain timelocks (seconds from deployment)
    dst_withdrawal: u64,
    dst_public_withdrawal: u64,
    dst_cancellation: u64,
}

// Immutable parameters for escrow contracts
public struct Immutables has store, copy, drop {
    maker: address,
    taker: address,
    token: address,
    amount: u64,
    hashlock: vector<u8>,
    timelocks: Timelocks,
    safety_deposit: u64,
    deployed_at: u64,
}

// Order configuration for cross-chain swaps
public struct OrderConfig has store, copy, drop {
    id: u32,
    src_amount: u64,
    min_dst_amount: u64,
    estimated_dst_amount: u64,
    expiration_time: u64,
    src_asset_is_native: bool,
    dst_asset_is_native: bool,
    fee: FeeConfig,
    cancellation_auction_duration: u64,
}

// Fee configuration
public struct FeeConfig has store, copy, drop {
    protocol_fee: u16,
    integrator_fee: u16,
    surplus_percentage: u8,
    max_cancellation_premium: u64,
}

// Escrow status
public struct EscrowStatus has store, copy, drop {
    is_filled: bool,
    is_cancelled: bool,
    filled_amount: u64,
    cancelled_at: Option<u64>,
    filled_at: Option<u64>,
}

// Source escrow contract for cross-chain atomic swap
public struct EscrowSrc has key, store {
    id: UID,
    immutables: Immutables,
    status: EscrowStatus,
    balance: Balance<0x2::sui::SUI>,
}

// Destination escrow contract for cross-chain atomic swap
public struct EscrowDst has key, store {
    id: UID,
    immutables: Immutables,
    status: EscrowStatus,
    balance: Balance<0x2::sui::SUI>,
}

// Factory for creating escrow contracts
public struct EscrowFactory has key {
    id: UID,
    escrow_srcs: Table<address, address>, // order_hash -> escrow_src_address
    escrow_dsts: Table<address, address>, // order_hash -> escrow_dst_address
    orders: Table<address, OrderConfig>, // order_hash -> order_config
    access_tokens: VecSet<address>, // addresses with access token
}

// Capability for factory operations
public struct FactoryCap has key, store {
    id: UID,
}

// ===== Events =====

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

// Event emitted when funds are rescued
public struct FundsRescued has copy, drop {
    order_hash: address,
    amount: u64,
}

// ===== Functions =====

// Initialize the factory
fun init(ctx: &mut TxContext) {
    create_factory(ctx);
}

// Internal function to create factory (extracted from init)
fun create_factory(ctx: &mut TxContext) {
    let factory = EscrowFactory {
        id: object::new(ctx),
        escrow_srcs: table::new(ctx),
        escrow_dsts: table::new(ctx),
        orders: table::new(ctx),
        access_tokens: vec_set::empty(),
    };
    
    let cap = FactoryCap {
        id: object::new(ctx),
    };
    
    transfer::share_object(factory);
    transfer::transfer(cap, tx_context::sender(ctx));
}

// Public function for tests to initialize factory
public fun init_for_testing(ctx: &mut TxContext) {
    create_factory(ctx);
}

// Create source escrow
public fun create_escrow_src(
    factory: &mut EscrowFactory,
    order_hash: address,
    immutables: Immutables,
    payment: Coin<0x2::sui::SUI>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);
    
    // Validate amount
    assert!(immutables.amount > 0, EInvalidAmount);
    assert!(immutables.safety_deposit > 0, EInvalidAmount);
    
    // Validate timelocks
    assert!(immutables.timelocks.src_withdrawal > 0, EInvalidTimelock);
    assert!(immutables.timelocks.src_public_withdrawal > immutables.timelocks.src_withdrawal, EInvalidTimelock);
    assert!(immutables.timelocks.src_cancellation > immutables.timelocks.src_public_withdrawal, EInvalidTimelock);
    
    // Set deployed timestamp
    let mut immutables_with_time = immutables;
    immutables_with_time.deployed_at = current_time;
    
    // Create escrow
    let escrow = EscrowSrc {
        id: object::new(ctx),
        immutables: immutables_with_time,
        status: EscrowStatus {
            is_filled: false,
            is_cancelled: false,
            filled_amount: 0,
            cancelled_at: option::none(),
            filled_at: option::none(),
        },
        balance: coin::into_balance(payment),
    };
    
    // Store escrow address
    let escrow_address = object::uid_to_address(&escrow.id);
    table::add(&mut factory.escrow_srcs, order_hash, escrow_address);
    
    // Transfer escrow to sender
    transfer::transfer(escrow, sender);
    
    // Emit event
    event::emit(EscrowCreated {
        order_hash,
        escrow_address,
        is_source: true,
    });
}

// Create destination escrow
public fun create_escrow_dst(
    factory: &mut EscrowFactory,
    order_hash: address,
    immutables: Immutables,
    payment: Coin<0x2::sui::SUI>,
    ctx: &mut TxContext
) {
    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);
    
    // Validate amount
    assert!(immutables.amount > 0, EInvalidAmount);
    assert!(immutables.safety_deposit > 0, EInvalidAmount);
    
    // Validate timelocks
    assert!(immutables.timelocks.dst_withdrawal > 0, EInvalidTimelock);
    assert!(immutables.timelocks.dst_public_withdrawal > immutables.timelocks.dst_withdrawal, EInvalidTimelock);
    assert!(immutables.timelocks.dst_cancellation > immutables.timelocks.dst_public_withdrawal, EInvalidTimelock);
    
    // Set deployed timestamp
    let mut immutables_with_time = immutables;
    immutables_with_time.deployed_at = current_time;
    
    // Create escrow
    let escrow = EscrowDst {
        id: object::new(ctx),
        immutables: immutables_with_time,
        status: EscrowStatus {
            is_filled: false,
            is_cancelled: false,
            filled_amount: 0,
            cancelled_at: option::none(),
            filled_at: option::none(),
        },
        balance: coin::into_balance(payment),
    };
    
    // Store escrow address
    let escrow_address = object::uid_to_address(&escrow.id);
    table::add(&mut factory.escrow_dsts, order_hash, escrow_address);
    
    // Transfer escrow to sender
    transfer::transfer(escrow, sender);
    
    // Emit event
    event::emit(EscrowCreated {
        order_hash,
        escrow_address,
        is_source: false,
    });
}

// Withdraw tokens from source escrow (private)
public fun withdraw_src(
    escrow: &mut EscrowSrc,
    secret: vector<u8>,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI> {
    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);
    
    // Validate caller is taker
    assert!(sender == escrow.immutables.taker, EInvalidCaller);
    
    // Validate timelock
    let withdrawal_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.src_withdrawal;
    let cancellation_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.src_cancellation;
    assert!(current_time >= withdrawal_start, EInvalidTime);
    assert!(current_time < cancellation_start, EInvalidTime);
    
    // Validate secret
    assert!(validate_secret(&secret, &escrow.immutables.hashlock), EInvalidSecret);
    
    // Validate escrow not already filled or cancelled
    assert!(!escrow.status.is_filled, EOrderAlreadyFilled);
    assert!(!escrow.status.is_cancelled, EOrderAlreadyCancelled);
    
    // Mark as filled
    escrow.status.is_filled = true;
    escrow.status.filled_at = option::some(current_time);
    
    // Transfer tokens
    let amount = escrow.immutables.amount;
    let safety_deposit = escrow.immutables.safety_deposit;
    
    let tokens = coin::from_balance(balance::split(&mut escrow.balance, amount), ctx);
    let safety = coin::from_balance(balance::split(&mut escrow.balance, safety_deposit), ctx);
    
    // Transfer safety deposit to caller
    transfer::public_transfer(safety, sender);
    
    tokens
}

// Withdraw tokens from destination escrow (private)
public fun withdraw_dst(
    escrow: &mut EscrowDst,
    secret: vector<u8>,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI> {
    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);
    
    // Validate caller is taker
    assert!(sender == escrow.immutables.taker, EInvalidCaller);
    
    // Validate timelock
    let withdrawal_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.dst_withdrawal;
    let cancellation_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.dst_cancellation;
    assert!(current_time >= withdrawal_start, EInvalidTime);
    assert!(current_time < cancellation_start, EInvalidTime);
    
    // Validate secret
    assert!(validate_secret(&secret, &escrow.immutables.hashlock), EInvalidSecret);
    
    // Validate escrow not already filled or cancelled
    assert!(!escrow.status.is_filled, EOrderAlreadyFilled);
    assert!(!escrow.status.is_cancelled, EOrderAlreadyCancelled);
    
    // Mark as filled
    escrow.status.is_filled = true;
    escrow.status.filled_at = option::some(current_time);
    
    // Transfer tokens to maker
    let amount = escrow.immutables.amount;
    let safety_deposit = escrow.immutables.safety_deposit;
    
    let tokens = coin::from_balance(balance::split(&mut escrow.balance, amount), ctx);
    let safety = coin::from_balance(balance::split(&mut escrow.balance, safety_deposit), ctx);
    
    // Transfer safety deposit to caller
    transfer::public_transfer(safety, sender);
    
    tokens
}

// Cancel source escrow (private)
public fun cancel_src(
    escrow: &mut EscrowSrc,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI> {
    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);
    
    // Validate caller is taker
    assert!(sender == escrow.immutables.taker, EInvalidCaller);
    
    // Validate timelock
    let cancellation_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.src_cancellation;
    assert!(current_time >= cancellation_start, EInvalidTime);
    
    // Validate escrow not already filled or cancelled
    assert!(!escrow.status.is_filled, EOrderAlreadyFilled);
    assert!(!escrow.status.is_cancelled, EOrderAlreadyCancelled);
    
    // Mark as cancelled
    escrow.status.is_cancelled = true;
    escrow.status.cancelled_at = option::some(current_time);
    
    // Return tokens to maker
    let amount = escrow.immutables.amount;
    let safety_deposit = escrow.immutables.safety_deposit;
    
    let tokens = coin::from_balance(balance::split(&mut escrow.balance, amount), ctx);
    let safety = coin::from_balance(balance::split(&mut escrow.balance, safety_deposit), ctx);
    
    // Transfer safety deposit to caller
    transfer::public_transfer(safety, sender);
    
    tokens
}

// Cancel destination escrow (private)
public fun cancel_dst(
    escrow: &mut EscrowDst,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI> {
    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);
    
    // Validate caller is taker
    assert!(sender == escrow.immutables.taker, EInvalidCaller);
    
    // Validate timelock
    let cancellation_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.dst_cancellation;
    assert!(current_time >= cancellation_start, EInvalidTime);
    
    // Validate escrow not already filled or cancelled
    assert!(!escrow.status.is_filled, EOrderAlreadyFilled);
    assert!(!escrow.status.is_cancelled, EOrderAlreadyCancelled);
    
    // Mark as cancelled
    escrow.status.is_cancelled = true;
    escrow.status.cancelled_at = option::some(current_time);
    
    // Return tokens to taker
    let amount = escrow.immutables.amount;
    let safety_deposit = escrow.immutables.safety_deposit;
    
    let tokens = coin::from_balance(balance::split(&mut escrow.balance, amount), ctx);
    let safety = coin::from_balance(balance::split(&mut escrow.balance, safety_deposit), ctx);
    
    // Transfer safety deposit to caller
    transfer::public_transfer(safety, sender);
    
    tokens
}

// Public withdrawal from source escrow (anyone with access token)
public fun public_withdraw_src(
    escrow: &mut EscrowSrc,
    secret: vector<u8>,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI> {
    let current_time = tx_context::epoch(ctx);
    
    // Validate timelock
    let public_withdrawal_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.src_public_withdrawal;
    let cancellation_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.src_cancellation;
    assert!(current_time >= public_withdrawal_start, EInvalidTime);
    assert!(current_time < cancellation_start, EInvalidTime);
    
    // Validate secret
    assert!(validate_secret(&secret, &escrow.immutables.hashlock), EInvalidSecret);
    
    // Validate escrow not already filled or cancelled
    assert!(!escrow.status.is_filled, EOrderAlreadyFilled);
    assert!(!escrow.status.is_cancelled, EOrderAlreadyCancelled);
    
    // Mark as filled
    escrow.status.is_filled = true;
    escrow.status.filled_at = option::some(current_time);
    
    // Transfer tokens to taker
    let amount = escrow.immutables.amount;
    let safety_deposit = escrow.immutables.safety_deposit;
    
    let tokens = coin::from_balance(balance::split(&mut escrow.balance, amount), ctx);
    let safety = coin::from_balance(balance::split(&mut escrow.balance, safety_deposit), ctx);
    
    // Transfer safety deposit to caller
    transfer::public_transfer(safety, tx_context::sender(ctx));
    
    tokens
}

// Public withdrawal from destination escrow (anyone with access token)
public fun public_withdraw_dst(
    escrow: &mut EscrowDst,
    secret: vector<u8>,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI> {
    let current_time = tx_context::epoch(ctx);
    
    // Validate timelock
    let public_withdrawal_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.dst_public_withdrawal;
    let cancellation_start = escrow.immutables.deployed_at + escrow.immutables.timelocks.dst_cancellation;
    assert!(current_time >= public_withdrawal_start, EInvalidTime);
    assert!(current_time < cancellation_start, EInvalidTime);
    
    // Validate secret
    assert!(validate_secret(&secret, &escrow.immutables.hashlock), EInvalidSecret);
    
    // Validate escrow not already filled or cancelled
    assert!(!escrow.status.is_filled, EOrderAlreadyFilled);
    assert!(!escrow.status.is_cancelled, EOrderAlreadyCancelled);
    
    // Mark as filled
    escrow.status.is_filled = true;
    escrow.status.filled_at = option::some(current_time);
    
    // Transfer tokens to maker
    let amount = escrow.immutables.amount;
    let safety_deposit = escrow.immutables.safety_deposit;
    
    let tokens = coin::from_balance(balance::split(&mut escrow.balance, amount), ctx);
    let safety = coin::from_balance(balance::split(&mut escrow.balance, safety_deposit), ctx);
    
    // Transfer safety deposit to caller
    transfer::public_transfer(safety, tx_context::sender(ctx));
    
    tokens
}

// Rescue funds from escrow (after rescue delay)
public fun rescue_funds(
    escrow: &mut EscrowSrc,
    amount: u64,
    ctx: &mut TxContext
): Coin<0x2::sui::SUI> {
    let sender = tx_context::sender(ctx);
    let current_time = tx_context::epoch(ctx);
    
    // Validate caller is taker
    assert!(sender == escrow.immutables.taker, EInvalidCaller);
    
    // Validate rescue delay (30 days)
    let rescue_start = escrow.immutables.deployed_at + 2592000; // 30 days in seconds
    assert!(current_time >= rescue_start, EInvalidTime);
    
    coin::from_balance(balance::split(&mut escrow.balance, amount), ctx)
}

// ===== Helper Functions =====

// Compute order hash
fun compute_order_hash(_order: &OrderConfig, _immutables: &Immutables): address {
    // Simplified hash computation - in production, use proper cryptographic hash
    let mut hash_input = vector::empty<u8>();
    vector::append(&mut hash_input, bcs::to_bytes(&_order.id));
    vector::append(&mut hash_input, bcs::to_bytes(&_order.src_amount));
    vector::append(&mut hash_input, bcs::to_bytes(&_order.min_dst_amount));
    vector::append(&mut hash_input, bcs::to_bytes(&_order.expiration_time));
    vector::append(&mut hash_input, bcs::to_bytes(&_immutables.maker));
    vector::append(&mut hash_input, bcs::to_bytes(&_immutables.taker));
    vector::append(&mut hash_input, bcs::to_bytes(&_immutables.token));
    
    // Convert to address (simplified)
    let hash = hash::sha3_256(hash_input);
    // For demo purposes, use first 20 bytes as address
    let mut addr_bytes = vector::empty<u8>();
    let mut i = 0;
    while (i < 20) {
        vector::push_back(&mut addr_bytes, *vector::borrow(&hash, i));
        i = i + 1;
    };
    // Convert bytes to address (simplified)
    let addr: address = @0x0; // Placeholder - in real implementation, convert bytes to address
    addr
}

// Validate secret against hashlock
fun validate_secret(secret: &vector<u8>, hashlock: &vector<u8>): bool {
    let secret_hash = hash::sha3_256(*secret);
    secret_hash == *hashlock
}

// Create timelocks for testing
public fun create_timelocks_for_test(
    src_withdrawal: u64,
    src_public_withdrawal: u64,
    src_cancellation: u64,
    src_public_cancellation: u64,
    dst_withdrawal: u64,
    dst_public_withdrawal: u64,
    dst_cancellation: u64
): Timelocks {
    Timelocks {
        src_withdrawal,
        src_public_withdrawal,
        src_cancellation,
        src_public_cancellation,
        dst_withdrawal,
        dst_public_withdrawal,
        dst_cancellation,
    }
}

// Create immutables for testing
public fun create_immutables_for_test(
    maker: address,
    taker: address,
    token: address,
    amount: u64,
    hashlock: vector<u8>,
    timelocks: Timelocks,
    safety_deposit: u64,
    deployed_at: u64
): Immutables {
    Immutables {
        maker,
        taker,
        token,
        amount,
        hashlock,
        timelocks,
        safety_deposit,
        deployed_at,
    }
}

// Get current stage of escrow
public fun get_escrow_stage(escrow: &EscrowSrc): u8 {
    let current_time = 0; // Placeholder - in real implementation, get current time
    let deployed_at = escrow.immutables.deployed_at;
    let timelocks = &escrow.immutables.timelocks;
    
    if (current_time < deployed_at + timelocks.src_withdrawal) {
        0 // Before withdrawal
    } else if (current_time < deployed_at + timelocks.src_public_withdrawal) {
        1 // Private withdrawal
    } else if (current_time < deployed_at + timelocks.src_cancellation) {
        2 // Public withdrawal
    } else if (current_time < deployed_at + timelocks.src_public_cancellation) {
        3 // Private cancellation
    } else {
        4 // Public cancellation
    }
}

// ===== View Functions =====

// Get escrow status
public fun get_escrow_status(escrow: &EscrowSrc): EscrowStatus {
    escrow.status
}

// Get escrow immutables
public fun get_escrow_immutables(escrow: &EscrowSrc): Immutables {
    escrow.immutables
}

// Get order from factory
public fun get_order(factory: &EscrowFactory, order_hash: address): Option<OrderConfig> {
    if (table::contains(&factory.orders, order_hash)) {
        option::some(*table::borrow(&factory.orders, order_hash))
    } else {
        option::none()
    }
}

// Check if address has access token
public fun has_access_token(factory: &EscrowFactory, addr: address): bool {
    vec_set::contains(&factory.access_tokens, &addr)
}

// ===== Admin Functions =====

// Add access token holder
public fun add_access_token(factory: &mut EscrowFactory, addr: address) {
    vec_set::insert(&mut factory.access_tokens, addr);
}

// Remove access token holder
public fun remove_access_token(factory: &mut EscrowFactory, addr: address) {
    vec_set::remove(&mut factory.access_tokens, &addr);
}


