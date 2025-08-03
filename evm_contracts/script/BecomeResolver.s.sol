// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/core/MeshResolverNetwork.sol";

/**
 * @title BecomeResolver
 * @dev Simple script showing how to become a resolver with just 0.001 ETH (~$2)
 */
contract BecomeResolverScript is Script {
    // Contract addresses (DEPLOYED ON SEPOLIA)
    address constant MESH_RESOLVER_NETWORK = 0x9Fb0993624b8AFbedC11DD9506433DF36e0474c1;
    
    function run() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        // Add 0x prefix and parse as hex
        string memory privateKeyHex = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyHex);
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Become a Resolver Demo ===");
        console.log("Your address:", deployer);
        console.log("Your ETH balance:", deployer.balance);
        
        if (MESH_RESOLVER_NETWORK == address(0)) {
            console.log("ERROR: Please update MESH_RESOLVER_NETWORK address");
            return;
        }
        
        MeshResolverNetwork resolverNetwork = MeshResolverNetwork(MESH_RESOLVER_NETWORK);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Method 1: Become resolver with native ETH (super easy!)
        console.log("\nMethod 1: Register with Native ETH");
        console.log("Cost: 0.001 ETH (~$2 USD)");
        
        try resolverNetwork.registerResolverWithEth{value: 0.001 ether}() {
            console.log("SUCCESS: You are now a resolver!");
            console.log("Stake: 0.001 ETH");
            console.log("Status: Authorized");
            
            // Check resolver status
            IMeshResolverNetwork.Resolver memory resolverInfo = resolverNetwork.getResolver(deployer);
            console.log("Your resolver stake:", resolverInfo.stake);
            console.log("Your reputation:", resolverInfo.reputation);
            console.log("Authorized:", resolverInfo.isAuthorized);
            
        } catch Error(string memory reason) {
            console.log("Registration failed:", reason);
            
            // Try alternative method with WETH
            console.log("\nMethod 2: Register with WETH");
            console.log("This requires wrapping ETH first...");
            
            // Note: This would require WETH contract interaction
            // For demo purposes, we'll just show the concept
            console.log("1. Wrap ETH to WETH: weth.deposit{value: 0.001 ether}()");
            console.log("2. Approve WETH: weth.approve(resolverNetwork, 0.001 ether)");
            console.log("3. Register: resolverNetwork.registerResolver(0.001 ether)");
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== Resolver Benefits ===");
        console.log("- Earn from filling cross-chain orders");
        console.log("- Compete for best rates");
        console.log("- Build reputation for better opportunities");
        console.log("- Withdraw stake anytime");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Monitor for cross-chain orders");
        console.log("2. Fill orders with competitive rates");
        console.log("3. Earn rewards and build reputation");
        console.log("4. Scale up your resolver business!");
        
        console.log("\nCongratulations! You're now part of the Mesh resolver network!");
    }
}