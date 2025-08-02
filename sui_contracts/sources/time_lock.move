/// @title time_lock
/// @dev Utility module for time lock functionality in Sui Move
module fusionplus::mesh_time_lock {
    use sui::clock::{Clock};

    /// Error codes
    #[allow(unused_const)]
    const E_INVALID_TIME_LOCK: u64 = 1;
    #[allow(unused_const)]
    const E_TIME_LOCK_EXPIRED: u64 = 2;

    /// Checks if the time lock has expired
    /// @param time_lock The time lock timestamp
    /// @param clock The clock reference
    /// @return bool True if expired
    public fun is_expired(time_lock: u64, clock: &Clock): bool {
        sui::clock::timestamp_ms(clock) > time_lock
    }

    /// Checks if the time lock is valid (future time)
    /// @param time_lock The time lock timestamp
    /// @param clock The clock reference
    /// @return bool True if valid
    public fun is_valid_time_lock(time_lock: u64, clock: &Clock): bool {
        time_lock > sui::clock::timestamp_ms(clock)
    }

    /// Gets the remaining time until expiration
    /// @param time_lock The time lock timestamp
    /// @param clock The clock reference
    /// @return u64 Remaining time in milliseconds (0 if expired)
    public fun get_remaining_time(time_lock: u64, clock: &Clock): u64 {
        let current_time = sui::clock::timestamp_ms(clock);
        if (current_time >= time_lock) {
            0
        } else {
            time_lock - current_time
        }
    }

    /// Generates a time lock for a specific duration from now
    /// @param duration Duration in milliseconds
    /// @param clock The clock reference
    /// @return u64 The time lock timestamp
    public fun generate_time_lock(duration: u64, clock: &Clock): u64 {
        sui::clock::timestamp_ms(clock) + duration
    }

    /// Standard time lock duration (1 hour in milliseconds)
    /// @return u64 Duration in milliseconds
    public fun standard_duration(): u64 {
        3600000 // 1 hour in milliseconds
    }

    /// Extended time lock duration (24 hours in milliseconds)
    /// @return u64 Duration in milliseconds
    public fun extended_duration(): u64 {
        86400000 // 24 hours in milliseconds
    }

    /// Short time lock duration (15 minutes in milliseconds)
    /// @return u64 Duration in milliseconds
    public fun short_duration(): u64 {
        900000 // 15 minutes in milliseconds
    }

    /// Checks if the time lock can be used for withdrawal
    /// @param time_lock The time lock timestamp
    /// @param clock The clock reference
    /// @return bool True if withdrawal is allowed
    public fun can_withdraw(time_lock: u64, clock: &Clock): bool {
        is_expired(time_lock, clock)
    }

    /// Checks if the time lock is still active
    /// @param time_lock The time lock timestamp
    /// @param clock The clock reference
    /// @return bool True if still active
    public fun is_active(time_lock: u64, clock: &Clock): bool {
        !is_expired(time_lock, clock)
    }

    /// Validates time lock parameters
    /// @param time_lock The time lock timestamp
    /// @param clock The clock reference
    /// @return bool True if valid
    public fun validate_time_lock(time_lock: u64, clock: &Clock): bool {
        is_valid_time_lock(time_lock, clock)
    }

    #[test_only]
    /// Test function for time lock functionality
    public fun test_time_lock_functionality(clock: &Clock) {
        let duration = standard_duration();
        let time_lock = generate_time_lock(duration, clock);
        
        assert!(is_valid_time_lock(time_lock, clock), E_INVALID_TIME_LOCK);
        assert!(is_active(time_lock, clock), E_TIME_LOCK_EXPIRED);
        assert!(!is_expired(time_lock, clock), E_TIME_LOCK_EXPIRED);
    }
} 