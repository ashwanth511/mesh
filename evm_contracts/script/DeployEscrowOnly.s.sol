// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MeshEscrow} from "../src/MeshEscrow.sol";

/**
 * @title DeployEscrowOnly
 * @dev Simple deployment script for MeshEscrow only (like unite-sui approach)
 * This allows direct HTLC swaps without the complex LimitOrderProtocol
 */
contract DeployEscrowOnly is Script {
    // Network-specific addresses
    address public constant WETH_SEPOLIA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address public constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // Deployment addresses
    address public meshEscrow;
    
    function run() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        string memory privateKeyHex = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyHex);
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log(" Deploying MeshEscrow Only (Direct HTLC Approach)");
        console.log("Deployer:", deployer);
        console.log("Network: Sepolia");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy MeshEscrow (HTLC) - Supports both WETH and native ETH
        meshEscrow = address(new MeshEscrow(WETH_SEPOLIA, deployer));
        console.log(" MeshEscrow deployed at:", meshEscrow);
        console.log("Supports: WETH and Native ETH");
        
        vm.stopBroadcast();
        
        console.log("\n === DEPLOYMENT COMPLETE ===");
        console.log("MeshEscrow (HTLC):", meshEscrow);
        console.log("WETH:", WETH_SEPOLIA);
        console.log("Deployer:", deployer);
        console.log("================================");
        
        console.log("\n Ready for direct HTLC swaps!");
        console.log(" Use this for simple cross-chain swaps like unite-sui");
        console.log(" No complex LimitOrderProtocol needed for basic swaps");
    }
} 