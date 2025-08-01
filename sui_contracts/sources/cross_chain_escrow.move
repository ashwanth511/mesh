/// @title Cross Chain Escrow
/// @dev Complete cross-chain escrow system for Sui to Ethereum swaps and vice versa
/// @dev Uses Hash-Time Lock Contract (HTLC) pattern for secure atomic swaps
#[allow(duplicate_alias,unused_const,unused_field)]
module fusionplus::mesh_escrow {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::object;
    use sui::transfer;
    use sui::tx_context;
    use std::string::String;
    use std::vector;
    use fusionplus::mesh_hash_lock;
    use fusionplus::mesh_time_lock;

    /// Error codes
    const E_INVALID_TIME_LOCK: u64 = 1;
    const E_INVALID_AMOUNT: u64 = 2;
    const E_NOT_TAKER: u64 = 3;
    const E_ALREADY_FILLED: u64 = 4;
    const E_EXPIRED: u64 = 5;
    const E_INVALID_SECRET: u64 = 6;
    const E_NOT_MAKER: u64 = 7;
    const E_NOT_EXPIRED: u64 = 8;
    const E_SECRET_ALREADY_USED: u64 = 9;
    const E_INSUFFICIENT_REMAINING_AMOUNT: u64 = 10;
    const E_INVALID_FILL_AMOUNT: u64 = 11;
    #[allow(unused_const)]
    const E_ESCROW_ALREADY_EXISTS: u64 = 12;
    #[allow(unused_const)]
    const E_ESCROW_NOT_FOUND: u64 = 13;

    /// Global registry for used secrets to prevent reuse across escrows
    public struct UsedSecretsRegistry has key {
        id: UID,
        used_secrets: vector<vector<u8>>,
    }

    /// Cross-chain escrow for any coin type
    public struct CrossChainEscrow<phantom T> has key, store {
        id: UID,
        maker: address,
        taker: address, // address(0x0) means anyone can fill
        total_amount: u64,
        remaining_amount: u64,
        balance: Balance<T>,
        hash_lock: vector<u8>,
        time_lock: u64,
        is_filled: bool,
        created_at: u64,
        ethereum_order_hash: String,
        secret: vector<u8>, // Revealed secret stored after completion
    }

    /// Factory for managing escrows
    public struct EscrowFactory has key {
        id: UID,
        escrows: vector<address>, // List of escrow addresses
        access_tokens: vector<address>, // Addresses with access tokens
    }

    /// Capability for factory operations
    public struct FactoryCap has key, store {
        id: UID,
    }

    /// Events
    public struct EscrowCreated has copy, drop {
        escrow_id: address,
        maker: address,
        taker: address,
        amount: u64,
        hash_lock: vector<u8>,
        time_lock: u64,
        ethereum_order_hash: String,
    }
    
    public struct EscrowPartiallyFilled has copy, drop {
        escrow_id: address,
        resolver: address,
        amount: u64,
        remaining_amount: u64,
        secret: vector<u8>,
        ethereum_order_hash: String,
    }
    
    public struct EscrowFilled has copy, drop {
        escrow_id: address,
        last_resolver: address,
        secret: vector<u8>,
        ethereum_order_hash: String,
    }

    public struct EscrowCancelled has copy, drop {
        escrow_id: address,
        maker: address,
        ethereum_order_hash: String,
    }

    public struct EscrowRefunded has copy, drop {
        escrow_id: address,
        maker: address,
        amount: u64,
        ethereum_order_hash: String,
    }

    /// Initialize the system
    fun init(ctx: &mut TxContext) {
        // Create global registry for used secrets
        let registry = UsedSecretsRegistry {
            id: object::new(ctx),
            used_secrets: vector::empty(),
        };
        transfer::share_object(registry);

        // Create factory
        let factory = EscrowFactory {
            id: object::new(ctx),
            escrows: vector::empty(),
            access_tokens: vector::empty(),
        };
        transfer::share_object(factory);

        // Create factory capability
        let cap = FactoryCap {
            id: object::new(ctx),
        };
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    /// Test initialization
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    /// Initiate atomic swap escrow
    public fun initiate_atomic_swap<T>(
        coin: Coin<T>,
        taker: address,
        hash_lock: vector<u8>,
        time_lock: u64,
        ethereum_order_hash: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): CrossChainEscrow<T> {
        let amount = coin::value(&coin);
        let maker = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        
        assert!(mesh_time_lock::is_valid_time_lock(time_lock, clock), E_INVALID_TIME_LOCK);
        assert!(amount > 0, E_INVALID_AMOUNT);
        assert!(mesh_hash_lock::is_valid_hash_lock(&hash_lock), E_INVALID_SECRET);
        
        let escrow = CrossChainEscrow<T> {
            id: object::new(ctx),
            maker,
            taker,
            total_amount: amount,
            remaining_amount: amount,
            balance: coin::into_balance(coin),
            hash_lock,
            time_lock,
            is_filled: false,
            created_at: current_time,
            ethereum_order_hash,
            secret: vector::empty(),
        };

        event::emit(EscrowCreated {
            escrow_id: object::uid_to_address(&escrow.id),
            maker,
            taker,
            amount,
            hash_lock,
            time_lock,
            ethereum_order_hash,
        });

        escrow
    }

    /// Initiate and share atomic swap (for public access)
    public fun initiate_and_share_atomic_swap<T>(
        coin: Coin<T>,
        taker: address,
        hash_lock: vector<u8>,
        time_lock: u64,
        ethereum_order_hash: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): address {
        let escrow = initiate_atomic_swap(coin, taker, hash_lock, time_lock, ethereum_order_hash, clock, ctx);
        let escrow_id = object::uid_to_address(&escrow.id);
        transfer::share_object(escrow);
        escrow_id
    }

    /// Execute atomic swap partially
    public fun execute_atomic_swap_partial<T>(
        escrow: &mut CrossChainEscrow<T>,
        registry: &mut UsedSecretsRegistry,
        amount: u64,
        secret: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<T> {
        let sender = tx_context::sender(ctx);
        let _current_time = clock::timestamp_ms(clock);
        
        // Validate caller
        if (escrow.taker != @0x0) {
            assert!(sender == escrow.taker, E_NOT_TAKER);
        };
        
        // Validate escrow state
        assert!(!escrow.is_filled, E_ALREADY_FILLED);
        assert!(!mesh_time_lock::is_expired(escrow.time_lock, clock), E_EXPIRED);
        assert!(mesh_hash_lock::validate_secret(secret, escrow.hash_lock), E_INVALID_SECRET);
        assert!(amount > 0, E_INVALID_FILL_AMOUNT);
        assert!(amount <= escrow.remaining_amount, E_INSUFFICIENT_REMAINING_AMOUNT);
        
        // Check secret usage
        if (vector::is_empty(&escrow.secret)) {
            // First execution - check if secret was used in other escrows
            assert!(!is_swap_secret_used(registry, &secret), E_SECRET_ALREADY_USED);
            escrow.secret = secret;
            vector::push_back(&mut registry.used_secrets, secret);
        } else {
            // Subsequent fills - must use same secret as first fill
            assert!(escrow.secret == secret, E_INVALID_SECRET);
        };
        
        // Update remaining amount
        escrow.remaining_amount = escrow.remaining_amount - amount;
        
        // Check if this completes the atomic swap
        let is_completed = escrow.remaining_amount == 0;
        if (is_completed) {
            escrow.is_filled = true;
        };
        
        // Transfer coins to resolver
        let coin = coin::from_balance(balance::split(&mut escrow.balance, amount), ctx);
        
        if (is_completed) {
            event::emit(EscrowFilled {
                escrow_id: object::uid_to_address(&escrow.id),
                last_resolver: sender,
                secret,
                ethereum_order_hash: escrow.ethereum_order_hash,
            });
        } else {
            event::emit(EscrowPartiallyFilled {
                escrow_id: object::uid_to_address(&escrow.id),
                resolver: sender,
                amount,
                remaining_amount: escrow.remaining_amount,
                secret,
                ethereum_order_hash: escrow.ethereum_order_hash,
            });
        };

        coin
    }
    
    /// Execute atomic swap completely (remaining amount)
    public fun execute_atomic_swap<T>(
        escrow: &mut CrossChainEscrow<T>,
        registry: &mut UsedSecretsRegistry,
        secret: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<T> {
        assert!(escrow.remaining_amount > 0, E_ALREADY_FILLED);
        
        // Execute with remaining amount
        let remaining_amount = escrow.remaining_amount;
        execute_atomic_swap_partial(escrow, registry, remaining_amount, secret, clock, ctx)
    }

    /// Reclaim atomic swap after timeout
    public fun reclaim_atomic_swap<T>(
        escrow: &mut CrossChainEscrow<T>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<T> {
        let sender = tx_context::sender(ctx);
        let _current_time = clock::timestamp_ms(clock);
        
        assert!(sender == escrow.maker, E_NOT_MAKER);
        assert!(!escrow.is_filled, E_ALREADY_FILLED);
        assert!(mesh_time_lock::is_expired(escrow.time_lock, clock), E_NOT_EXPIRED);
        let amount = escrow.remaining_amount;
        escrow.remaining_amount = 0;
        
        // Transfer remaining balance to maker
        let coin = coin::from_balance(balance::withdraw_all(&mut escrow.balance), ctx);
        
        event::emit(EscrowRefunded {
            escrow_id: object::uid_to_address(&escrow.id),
            maker: sender,
            amount,
            ethereum_order_hash: escrow.ethereum_order_hash,
        });

        coin
    }

    /// Utility functions - use hash_lock module directly
    
    /// Share atomic swap as shared object
    public fun share_atomic_swap<T>(escrow: CrossChainEscrow<T>) {
        transfer::share_object(escrow);
    }
    
    /// Validate secret against hash lock
    public fun validate_secret(secret: vector<u8>, hash_lock: vector<u8>): bool {
        mesh_hash_lock::validate_secret(secret, hash_lock)
    }

    /// Generate hash lock from secret
    public fun generate_hash_lock(secret: vector<u8>): vector<u8> {
        mesh_hash_lock::generate_hash_lock(secret)
    }

    /// Get atomic swap information
    public fun get_atomic_swap_info<T>(escrow: &CrossChainEscrow<T>): (
        address, address, u64, u64, vector<u8>, u64, bool, u64, String
    ) {
        (
            escrow.maker,
            escrow.taker,
            escrow.total_amount,
            escrow.remaining_amount,
            escrow.hash_lock,
            escrow.time_lock,
            escrow.is_filled,
            escrow.created_at,
            escrow.ethereum_order_hash
        )
    }
    
    /// Get remaining swap amount
    public fun get_remaining_swap_amount<T>(escrow: &CrossChainEscrow<T>): u64 {
        escrow.remaining_amount
    }

    /// Check if atomic swap is expired
    public fun is_atomic_swap_expired<T>(escrow: &CrossChainEscrow<T>, clock: &Clock): bool {
        mesh_time_lock::is_expired(escrow.time_lock, clock)
    }

    /// Check if atomic swap can be executed
    public fun can_execute_atomic_swap<T>(escrow: &CrossChainEscrow<T>, clock: &Clock): bool {
        !escrow.is_filled && mesh_time_lock::is_active(escrow.time_lock, clock)
    }

    /// Get revealed swap secret
    public fun get_swap_secret<T>(escrow: &CrossChainEscrow<T>): vector<u8> {
        escrow.secret
    }

    /// Check if swap secret is used
    public fun is_swap_secret_used(registry: &UsedSecretsRegistry, secret: &vector<u8>): bool {
        let mut i = 0;
        let len = vector::length(&registry.used_secrets);
        while (i < len) {
            let used_secret = vector::borrow(&registry.used_secrets, i);
            if (used_secret == secret) {
                return true
            };
            i = i + 1;
        };
        false
    }

    /// Get used swap secrets count
    public fun get_used_swap_secrets_count(registry: &UsedSecretsRegistry): u64 {
        vector::length(&registry.used_secrets)
    }

    /// Generate batch hash locks (for testing)
    public fun generate_batch_hash_locks(secrets: vector<vector<u8>>): vector<vector<u8>> {
        mesh_hash_lock::generate_batch_hash_locks(secrets)
    }

    /// Factory functions
    public fun add_escrow_to_factory(factory: &mut EscrowFactory, escrow_id: address) {
        vector::push_back(&mut factory.escrows, escrow_id);
    }

    public fun add_access_token(factory: &mut EscrowFactory, addr: address) {
        vector::push_back(&mut factory.access_tokens, addr);
    }

    public fun remove_access_token(factory: &mut EscrowFactory, addr: address) {
        let mut i = 0;
        let len = vector::length(&factory.access_tokens);
        while (i < len) {
            let token_addr = *vector::borrow(&factory.access_tokens, i);
            if (token_addr == addr) {
                vector::remove(&mut factory.access_tokens, i);
                break
            };
            i = i + 1;
        };
    }

    public fun has_access_token(factory: &EscrowFactory, addr: address): bool {
        let mut i = 0;
        let len = vector::length(&factory.access_tokens);
        while (i < len) {
            let token_addr = *vector::borrow(&factory.access_tokens, i);
            if (token_addr == addr) {
                return true
            };
            i = i + 1;
        };
        false
    }

    public fun get_escrow_count(factory: &EscrowFactory): u64 {
        vector::length(&factory.escrows)
    }
} 