// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TimeLock
 * @dev Utility library for time lock operations
 */
library TimeLock {
    /**
     * @dev Validates if a time lock is valid
     * @param timeLock The time lock to validate
     * @return valid True if the time lock is valid
     */
    function isValidTimeLock(uint256 timeLock) internal view returns (bool valid) {
        valid = timeLock > block.timestamp;
    }

    /**
     * @dev Checks if a time lock has expired
     * @param timeLock The time lock to check
     * @return expired True if the time lock has expired
     */
    function isExpired(uint256 timeLock) internal view returns (bool expired) {
        expired = block.timestamp >= timeLock;
    }

    /**
     * @dev Calculates time remaining until expiration
     * @param timeLock The time lock to check
     * @return remaining Time remaining in seconds
     */
    function timeRemaining(uint256 timeLock) internal view returns (uint256 remaining) {
        if (block.timestamp >= timeLock) {
            remaining = 0;
        } else {
            remaining = timeLock - block.timestamp;
        }
    }

    /**
     * @dev Creates a time lock with a duration from now
     * @param duration Duration in seconds
     * @return timeLock The calculated time lock
     */
    function createTimeLock(uint256 duration) internal view returns (uint256 timeLock) {
        timeLock = block.timestamp + duration;
    }

    /**
     * @dev Validates time lock duration
     * @param duration Duration in seconds
     * @param minDuration Minimum allowed duration
     * @param maxDuration Maximum allowed duration
     * @return valid True if duration is valid
     */
    function isValidDuration(
        uint256 duration,
        uint256 minDuration,
        uint256 maxDuration
    ) internal pure returns (bool valid) {
        valid = duration >= minDuration && duration <= maxDuration;
    }
} 