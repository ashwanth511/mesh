/// @title hash_lock
/// @dev Utility module for hash lock functionality in Sui Move
module fusionplus::mesh_hash_lock {
    use sui::hash;

    /// Error codes
    #[allow(unused_const)]
    const E_INVALID_SECRET: u64 = 1;
    #[allow(unused_const)]
    const E_INVALID_HASH_LOCK: u64 = 2;
    const E_EMPTY_SECRET: u64 = 3;

    /// Validates if a secret matches the hash lock
    /// @param secret The secret to validate
    /// @param hash_lock The hash lock to validate against
    /// @return bool True if the secret is valid
    public fun validate_secret(secret: vector<u8>, hash_lock: vector<u8>): bool {
        if (std::vector::is_empty(&secret)) {
            return false
        };
        
        let computed_hash = hash::keccak256(&secret);
        computed_hash == hash_lock
    }

    /// Generates a hash lock from a secret
    /// @param secret The secret to hash
    /// @return vector<u8> The resulting hash lock
    public fun generate_hash_lock(secret: vector<u8>): vector<u8> {
        assert!(!std::vector::is_empty(&secret), E_EMPTY_SECRET);
        hash::keccak256(&secret)
    }

    /// Validates hash lock format
    /// @param hash_lock The hash lock to validate
    /// @return bool True if valid
    public fun is_valid_hash_lock(hash_lock: &vector<u8>): bool {
        !std::vector::is_empty(hash_lock) && std::vector::length(hash_lock) == 32
    }

    /// Generates a test secret (for testing purposes)
    /// @param seed A seed value for generation
    /// @return vector<u8> A test secret
    public fun generate_test_secret(seed: u64): vector<u8> {
        let mut secret = std::vector::empty<u8>();
        let mut i = 0;
        while (i < 32) {
            let byte = ((seed + i) % 256) as u8;
            std::vector::push_back(&mut secret, byte);
            i = i + 1;
        };
        secret
    }

    /// Batch generates hash locks from multiple secrets
    /// @param secrets Vector of secrets
    /// @return vector<vector<u8>> Vector of hash locks
    public fun generate_batch_hash_locks(secrets: vector<vector<u8>>): vector<vector<u8>> {
        let mut result = std::vector::empty();
        let mut i = 0;
        let len = std::vector::length(&secrets);
        while (i < len) {
            let secret = std::vector::borrow(&secrets, i);
            let hash_lock = hash::keccak256(secret);
            std::vector::push_back(&mut result, hash_lock);
            i = i + 1;
        };
        result
    }

    /// Compares two hash locks for equality
    /// @param hash_lock1 First hash lock
    /// @param hash_lock2 Second hash lock
    /// @return bool True if equal
    public fun are_equal(hash_lock1: &vector<u8>, hash_lock2: &vector<u8>): bool {
        hash_lock1 == hash_lock2
    }

    #[test_only]
    /// Test function for hash lock validation
    public fun test_hash_lock_functionality() {
        let secret = b"test_secret";
        let hash_lock = generate_hash_lock(secret);
        assert!(validate_secret(secret, hash_lock), E_INVALID_SECRET);
        
        let wrong_secret = b"wrong_secret";
        assert!(!validate_secret(wrong_secret, hash_lock), E_INVALID_SECRET);
    }
} 