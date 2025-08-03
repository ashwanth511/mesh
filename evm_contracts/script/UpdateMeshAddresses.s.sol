// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MeshDutchAuction} from "../src/core/MeshDutchAuction.sol";
import {MeshResolverNetwork} from "../src/core/MeshResolverNetwork.sol";

/**
 * @title UpdateMeshAddresses
 * @dev Separate script to update contract addresses after deployment
 * This is useful when deployment fails and we need to update addresses
 */
contract UpdateMeshAddresses is Script {
    
    function run() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        // Add 0x prefix and parse as hex
        string memory privateKeyHex = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyHex);
        address deployer = vm.addr(deployerPrivateKey);
        
        // Contract addresses - UPDATED WITH ACTUAL DEPLOYED ADDRESSES
        address meshDutchAuction = 0x89003BF91d4AB54eF093f13f513b9d99Cb808832;
        address meshResolverNetwork = 0x2A08aEA944aC4813Eb9Ff2621c417dd3B1F14a6a;
        address meshLimitOrderProtocol = 0xE5638Bce0050975aE6f0f475B8d399C929Fb0C42;
        
        console.log("Updating Mesh contract addresses with deployer:", deployer);
        console.log("DutchAuction:", meshDutchAuction);
        console.log("ResolverNetwork:", meshResolverNetwork);
        console.log("LimitOrderProtocol:", meshLimitOrderProtocol);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Update MeshDutchAuction with the final LimitOrderProtocol address
        MeshDutchAuction dutchAuction = MeshDutchAuction(meshDutchAuction);
        dutchAuction.setLimitOrderProtocol(meshLimitOrderProtocol);
        console.log("MeshDutchAuction updated with final LimitOrderProtocol address");
        
        // Update MeshResolverNetwork with the final LimitOrderProtocol address
        MeshResolverNetwork resolverNet = MeshResolverNetwork(meshResolverNetwork);
        resolverNet.setLimitOrderProtocol(meshLimitOrderProtocol);
        console.log(" MeshResolverNetwork updated with final LimitOrderProtocol address");
        
        vm.stopBroadcast();
        
        console.log("\n=== Address Update Complete ===");
        console.log("All contracts now point to the correct LimitOrderProtocol address");
        console.log("Ready for testing and usage!");
    }
    
    /**
     * @dev Alternative function to update only DutchAuction
     */
    function updateDutchAuctionOnly() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        string memory privateKeyHex = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyHex);
        
        address meshDutchAuction = 0x89003BF91d4AB54eF093f13f513b9d99Cb808832;
        address meshLimitOrderProtocol = 0xE5638Bce0050975aE6f0f475B8d399C929Fb0C42;
        
        vm.startBroadcast(deployerPrivateKey);
        
        MeshDutchAuction dutchAuction = MeshDutchAuction(meshDutchAuction);
        dutchAuction.setLimitOrderProtocol(meshLimitOrderProtocol);
        console.log("DutchAuction updated");
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev Alternative function to update only ResolverNetwork
     */
    function updateResolverNetworkOnly() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        string memory privateKeyHex = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyHex);
        
        address meshResolverNetwork = 0x2A08aEA944aC4813Eb9Ff2621c417dd3B1F14a6a;
        address meshLimitOrderProtocol = 0xE5638Bce0050975aE6f0f475B8d399C929Fb0C42;
        
        vm.startBroadcast(deployerPrivateKey);
        
        MeshResolverNetwork resolverNet = MeshResolverNetwork(meshResolverNetwork);
        resolverNet.setLimitOrderProtocol(meshLimitOrderProtocol);
        console.log("ResolverNetwork updated");
        
        vm.stopBroadcast();
    }
}