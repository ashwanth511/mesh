module fusionplus::complete_swap {
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use fusionplus::mesh_escrow::{Self, CrossChainEscrow, UsedSecretsRegistry};
    use fusionplus::mesh_hash_lock;
    use fusionplus::mesh_time_lock;
    use std::debug;
    use std::string::{Self, String};

    /// Complete ETH to SUI swap by creating matching escrow
    public fun complete_eth_to_sui_swap(
        sui_coin: Coin<SUI>,
        user_sui_address: address,
        ethereum_hash_lock: vector<u8>,
        ethereum_order_hash: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): CrossChainEscrow<SUI> {
        // Create time lock (1 hour from now)
        let time_lock = mesh_time_lock::generate_time_lock(3600000, clock);
        
        // Create escrow with same hash lock as Ethereum
        let escrow = mesh_escrow::initiate_atomic_swap(
            sui_coin,
            user_sui_address, // User's Sui wallet address
            ethereum_hash_lock, // Same hash lock as Ethereum
            time_lock,
            ethereum_order_hash,
            clock,
            ctx
        );

        debug::print(&string::utf8(b"✅ Matching Sui escrow created!"));
        debug::print(&string::utf8(b"🔒 Hash Lock: "));
        debug::print(&ethereum_hash_lock);
        debug::print(&string::utf8(b"⏰ Time Lock: "));
        debug::print(&time_lock);
        debug::print(&string::utf8(b"📋 Order Hash: "));
        debug::print(&ethereum_order_hash);

        escrow
    }

    /// Execute the swap by revealing the secret
    public fun execute_swap(
        escrow: &mut CrossChainEscrow<SUI>,
        registry: &mut UsedSecretsRegistry,
        secret: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        debug::print(&string::utf8(b"🔄 Executing swap with secret..."));
        
        // Execute the atomic swap
        let coin = mesh_escrow::execute_atomic_swap(
            escrow,
            registry,
            secret,
            clock,
            ctx
        );

        debug::print(&string::utf8(b"✅ Swap executed successfully!"));
        debug::print(&string::utf8(b"💰 Claimed SUI amount: "));
        debug::print(&coin::value(&coin));

        coin
    }

    /// Get escrow information
    public fun get_escrow_info<T>(escrow: &CrossChainEscrow<T>): (
        address, address, u64, u64, vector<u8>, u64, bool, u64, String
    ) {
        mesh_escrow::get_atomic_swap_info(escrow)
    }

    /// Check if escrow can be executed
    public fun can_execute<T>(escrow: &CrossChainEscrow<T>, clock: &Clock): bool {
        mesh_escrow::can_execute_atomic_swap(escrow, clock)
    }

    /// Check if escrow is expired
    public fun is_expired<T>(escrow: &CrossChainEscrow<T>, clock: &Clock): bool {
        mesh_escrow::is_atomic_swap_expired(escrow, clock)
    }
} 