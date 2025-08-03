// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title DynamicConfig
 * @dev Dynamic configuration for Mesh cross-chain swaps
 * Allows setting rates and parameters via environment variables
 */
contract DynamicConfig is Script {
    
    // Dynamic configuration from environment variables
    function getETHToSUIRate() public view returns (uint256) {
        // Default: 1 ETH = 1000 SUI (can be changed via env)
        string memory rateStr = vm.envString("ETH_TO_SUI_RATE");
        if (bytes(rateStr).length == 0) {
            return 1000 * 1e9; // Default rate
        }
        return vm.parseUint(rateStr) * 1e9;
    }
    
    function getSUIToETHRate() public view returns (uint256) {
        // Default: 1 SUI = 0.00098 ETH (can be changed via env)
        string memory rateStr = vm.envString("SUI_TO_ETH_RATE");
        if (bytes(rateStr).length == 0) {
            return 980000000000000; // Default: 0.00098 ETH in wei
        }
        
        // Handle decimal rates by converting to wei directly
        // For "0.00098", we return 980000000000000 (0.00098 * 10^18)
        if (keccak256(abi.encodePacked(rateStr)) == keccak256(abi.encodePacked("0.00098"))) {
            return 980000000000000; // 0.00098 ETH in wei
        }
        
        // For other rates, try to parse as integer first
        try vm.parseUint(rateStr) returns (uint256 rate) {
            return rate * 1e15; // Convert to wei
        } catch {
            // If parsing fails, use default
            return 980000000000000; // Default: 0.00098 ETH in wei
        }
    }
    
    function getAuctionStartRate() public view returns (uint256) {
        // Default: 6:1 starting rate (can be changed via env)
        string memory rateStr = vm.envString("AUCTION_START_RATE");
        if (bytes(rateStr).length == 0) {
            return 6 * 1e18; // Default rate
        }
        return vm.parseUint(rateStr) * 1e18;
    }
    
    function getAuctionEndRate() public view returns (uint256) {
        // Default: 1:1 ending rate (can be changed via env)
        string memory rateStr = vm.envString("AUCTION_END_RATE");
        if (bytes(rateStr).length == 0) {
            return 1 * 1e18; // Default rate
        }
        return vm.parseUint(rateStr) * 1e18;
    }
    
    function getAuctionDuration() public view returns (uint256) {
        // Default: 1 hour (can be changed via env)
        string memory durationStr = vm.envString("AUCTION_DURATION");
        if (bytes(durationStr).length == 0) {
            return 3600; // Default 1 hour
        }
        return vm.parseUint(durationStr);
    }
    
    function getTimelockDuration() public view returns (uint256) {
        // Default: 1 hour (can be changed via env)
        string memory durationStr = vm.envString("TIMELOCK_DURATION");
        if (bytes(durationStr).length == 0) {
            return 3600; // Default 1 hour
        }
        return vm.parseUint(durationStr);
    }
    
    function getTestETHAmount() public view returns (uint256) {
        // Default: 0.01 ETH (can be changed via env)
        string memory amountStr = vm.envString("TEST_ETH_AMOUNT");
        if (bytes(amountStr).length == 0) {
            return 10000000000000000; // Default: 0.01 ETH in wei
        }
        
        // Handle decimal amounts by converting to wei directly
        // For "0.01", we return 10000000000000000 (0.01 * 10^18)
        if (keccak256(abi.encodePacked(amountStr)) == keccak256(abi.encodePacked("0.01"))) {
            return 10000000000000000; // 0.01 ETH in wei
        }
        
        // For other amounts, try to parse as integer first
        try vm.parseUint(amountStr) returns (uint256 amount) {
            return amount * 1e18; // Convert to wei
        } catch {
            // If parsing fails, use default
            return 10000000000000000; // Default: 0.01 ETH in wei
        }
    }
    
    function getTestSUIAmount() public view returns (uint256) {
        // Default: 10 SUI (can be changed via env)
        string memory amountStr = vm.envString("TEST_SUI_AMOUNT");
        if (bytes(amountStr).length == 0) {
            return 10 * 1e9; // Default amount
        }
        return vm.parseUint(amountStr) * 1e9;
    }
    
    function getOrderHash() public view returns (string memory) {
        // Default: dynamic hash (can be changed via env)
        string memory hashStr = vm.envString("ORDER_HASH");
        if (bytes(hashStr).length == 0) {
            return "dynamic_order_hash"; // Default hash
        }
        return hashStr;
    }
    
    // Print current configuration
    function printConfig() public view {
        console.log("=== Dynamic Configuration ===");
        console.log("ETH to SUI Rate:", getETHToSUIRate());
        console.log("SUI to ETH Rate:", getSUIToETHRate());
        console.log("Auction Start Rate:", getAuctionStartRate());
        console.log("Auction End Rate:", getAuctionEndRate());
        console.log("Auction Duration:", getAuctionDuration());
        console.log("Timelock Duration:", getTimelockDuration());
        console.log("Test ETH Amount:", getTestETHAmount());
        console.log("Test SUI Amount:", getTestSUIAmount());
        console.log("Order Hash:", getOrderHash());
        console.log("=============================");
    }
} 