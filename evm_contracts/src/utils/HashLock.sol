// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HashLock
 * @dev Utility library for hash lock operations
 */
library HashLock {
    /**
     * @dev Generates a hash lock from a secret
     * @param secret The secret to hash
     * @return hashLock The hash of the secret
     */
    function generateHashLock(bytes32 secret) internal pure returns (bytes32 hashLock) {
        hashLock = keccak256(abi.encodePacked(secret));
    }

    /**
     * @dev Validates a secret against a hash lock
     * @param secret The secret to validate
     * @param hashLock The hash lock to validate against
     * @return valid True if the secret matches the hash lock
     */
    function validateSecret(bytes32 secret, bytes32 hashLock) internal pure returns (bool valid) {
        valid = keccak256(abi.encodePacked(secret)) == hashLock;
    }

    /**
     * @dev Generates a random secret
     * @param nonce A nonce for randomness
     * @return secret A random secret
     */
    function generateSecret(uint256 nonce) internal view returns (bytes32 secret) {
        secret = keccak256(abi.encodePacked(
            block.timestamp,
            block.number,
            nonce,
            msg.sender
        ));
    }
} 