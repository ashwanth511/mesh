// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title HashLock
 * @dev Utility library for hash-time lock functionality
 */
library HashLock {
    /**
     * @dev Verifies if a secret matches the hash lock
     * @param secret The secret to verify
     * @param hashLock The hash lock to verify against
     * @return bool True if the secret is valid
     */
    function verifySecret(
        bytes32 secret,
        bytes32 hashLock
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(secret)) == hashLock;
    }

    /**
     * @dev Creates a hash lock from a secret
     * @param secret The secret to hash
     * @return bytes32 The resulting hash lock
     */
    function createHashLock(bytes32 secret) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(secret));
    }

    /**
     * @dev Generates a random secret (for testing purposes)
     * @return bytes32 A random secret
     */
    function generateSecret() internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender));
    }

    /**
     * @dev Validates hash lock format
     * @param hashLock The hash lock to validate
     * @return bool True if valid
     */
    function isValidHashLock(bytes32 hashLock) internal pure returns (bool) {
        return hashLock != bytes32(0);
    }
} 