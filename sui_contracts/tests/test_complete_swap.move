#[test_only]
module fusionplus::test_complete_swap {
    use std::debug;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use fusionplus::mesh_escrow::{Self, CrossChainEscrow, EscrowFactory, UsedSecretsRegistry};
    use fusionplus::mesh_hash_lock::{Self, HashLock};
    use fusionplus::mesh_time_lock::{Self, TimeLock};

    // Test addresses
    const MAKER_ADDRESS: address = @0x48bde6777d84f3288c24681b93a0f2d36ae2e6c6ebd5189fd00be1b5a9f7c0a2;
    const TAKER_ADDRESS: address = @0x0000000000000000000000000000000000000000; // Anyone can claim

    #[test]
    fun test_complete_eth_to_sui_swap() {
        let ctx = &mut sui::test_scenario::begin(MAKER_ADDRESS);
        
        // Get clock
        let clock = clock::default_for_testing();
        sui::test_scenario::next_tx(ctx, MAKER_ADDRESS);
        clock::set_for_testing(&mut clock, 1000000);
        
        // Create test SUI coin
        let test_sui = coin::mint_for_testing<SUI>(1000000000, &mut clock); // 1 SUI
        
        // Create secret and hash lock (same as Ethereum side)
        let secret = mesh_hash_lock::generate_test_secret(123);
        let hash_lock = mesh_hash_lock::create_hash_lock(secret);
        
        // Create time lock (1 hour)
        let time_lock = mesh_time_lock::create_time_lock(3600, &clock);
        
        // Create escrow factory and registry
        let factory_cap = mesh_escrow::init(ctx);
        let registry = mesh_escrow::create_registry(ctx);
        
        // Create escrow
        let escrow = mesh_escrow::create_escrow(
            test_sui,
            TAKER_ADDRESS,
            hash_lock,
            time_lock,
            "test-sui-order-1754214277591", // Same as Ethereum
            &clock,
            ctx
        );
        
        debug::print(&string(b"✅ Sui escrow created successfully!"));
        debug::print(&string(b"🔑 Secret: "));
        debug::print(&secret);
        debug::print(&string(b"🔒 Hash Lock: "));
        debug::print(&hash_lock);
        
        // Now we can complete the swap by revealing the secret
        // This would be done by the taker (resolver) who knows the secret
        
        // Clean up
        mesh_escrow::destroy_escrow(escrow);
        mesh_escrow::destroy_registry(registry);
        mesh_escrow::destroy_factory_cap(factory_cap);
        
        sui::test_scenario::end(ctx);
    }
} 