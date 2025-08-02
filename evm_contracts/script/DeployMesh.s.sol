// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MeshEscrow} from "../src/MeshEscrow.sol";
import {MeshLimitOrderProtocol} from "../src/MeshLimitOrderProtocol.sol";
import {MeshDutchAuction} from "../src/core/MeshDutchAuction.sol";
import {MeshResolverNetwork} from "../src/core/MeshResolverNetwork.sol";
import {MeshCrossChainOrder} from "../src/core/MeshCrossChainOrder.sol";

/**
 * @title DeployMesh
 * @dev Complete deployment script for Mesh 1inch Fusion+ contracts
 */
contract DeployMesh is Script {
    // Network-specific addresses
    address public constant WETH_SEPOLIA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address public constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // Deployment addresses
    address public meshEscrow;
    address public meshDutchAuction;
    address public meshResolverNetwork;
    address public meshLimitOrderProtocol;
    address public meshCrossChainOrder;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying Mesh 1inch Fusion+ contracts with deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy MeshEscrow (HTLC) - Supports both WETH and native ETH
        meshEscrow = address(new MeshEscrow(WETH_SEPOLIA, deployer));
        console.log("MeshEscrow deployed at:", meshEscrow);
        console.log("Supports: WETH and Native ETH");
        
        // 2. Deploy MeshDutchAuction
        meshDutchAuction = address(new MeshDutchAuction(address(0))); // Will be updated after LOP deployment
        console.log("MeshDutchAuction deployed at:", meshDutchAuction);
        
        // 3. Deploy MeshResolverNetwork
        meshResolverNetwork = address(new MeshResolverNetwork(address(0), WETH_SEPOLIA, deployer)); // Will be updated after LOP deployment
        console.log("MeshResolverNetwork deployed at:", meshResolverNetwork);
        
        // 4. Deploy MeshLimitOrderProtocol (main orchestrator)
        meshLimitOrderProtocol = address(new MeshLimitOrderProtocol(
            WETH_SEPOLIA,
            meshDutchAuction,
            meshResolverNetwork,
            meshEscrow
        ));
        console.log("MeshLimitOrderProtocol deployed at:", meshLimitOrderProtocol);
        
        // 5. Deploy MeshCrossChainOrder
        meshCrossChainOrder = address(new MeshCrossChainOrder(
            WETH_SEPOLIA,
            meshLimitOrderProtocol,
            meshEscrow
        ));
        console.log("MeshCrossChainOrder deployed at:", meshCrossChainOrder);
        
        vm.stopBroadcast();
        
        console.log("\n=== Complete Mesh 1inch Fusion+ Deployment Summary ===");
        console.log("MeshEscrow (HTLC):", meshEscrow);
        console.log("MeshDutchAuction:", meshDutchAuction);
        console.log("MeshResolverNetwork:", meshResolverNetwork);
        console.log("MeshLimitOrderProtocol:", meshLimitOrderProtocol);
        console.log("MeshCrossChainOrder:", meshCrossChainOrder);
        console.log("WETH:", WETH_SEPOLIA);
        console.log("Deployer:", deployer);
        console.log("=====================================================\n");
        
        // Verify deployment
        _verifyDeployment();
    }
    
    function _verifyDeployment() internal view {
        // Verify MeshEscrow
        MeshEscrow escrow = MeshEscrow(payable(meshEscrow));
        require(address(escrow.weth()) == WETH_SEPOLIA, "Invalid WETH address in escrow");
        require(escrow.owner() == vm.addr(vm.envUint("PRIVATE_KEY")), "Invalid owner in escrow");
        
        // Verify MeshLimitOrderProtocol
        MeshLimitOrderProtocol lop = MeshLimitOrderProtocol(meshLimitOrderProtocol);
        require(address(lop.weth()) == WETH_SEPOLIA, "Invalid WETH address in LOP");
        require(address(lop.dutchAuction()) == meshDutchAuction, "Invalid DutchAuction address in LOP");
        require(address(lop.resolverNetwork()) == meshResolverNetwork, "Invalid ResolverNetwork address in LOP");
        require(address(lop.escrowContract()) == meshEscrow, "Invalid Escrow address in LOP");
        
        // Verify MeshCrossChainOrder
        MeshCrossChainOrder cco = MeshCrossChainOrder(meshCrossChainOrder);
        require(address(cco.weth()) == WETH_SEPOLIA, "Invalid WETH address in CCO");
        require(address(cco.limitOrderProtocol()) == meshLimitOrderProtocol, "Invalid LOP address in CCO");
        require(address(cco.escrowContract()) == meshEscrow, "Invalid Escrow address in CCO");
        
        console.log("Complete deployment verification passed!");
        console.log("All Mesh 1inch Fusion+ contracts are ready!");
    }
} 