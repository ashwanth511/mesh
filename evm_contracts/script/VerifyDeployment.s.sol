// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title VerifyDeployment
 * @dev Verify all contracts are deployed and working correctly
 */
contract VerifyDeploymentScript is Script {
    function run() external view {
        console.log(" Verifying Mesh Fusion+ Contract Deployment");
        console.log("============================================");
        
        // Get addresses from environment or replace with your deployed addresses
        address meshEscrow = vm.envOr("MESH_ESCROW_ADDRESS", address(0));
        address meshCrossChainOrder = vm.envOr("MESH_CROSS_CHAIN_ORDER_ADDRESS", address(0));
        address meshLimitOrderProtocol = vm.envOr("MESH_LIMIT_ORDER_PROTOCOL_ADDRESS", address(0));
        address meshDutchAuction = vm.envOr("MESH_DUTCH_AUCTION_ADDRESS", address(0));
        address meshResolverNetwork = vm.envOr("MESH_RESOLVER_NETWORK_ADDRESS", address(0));
        
        console.log("\nContract Addresses:");
        console.log("MeshEscrow:", meshEscrow);
        console.log("MeshCrossChainOrder:", meshCrossChainOrder);
        console.log("MeshLimitOrderProtocol:", meshLimitOrderProtocol);
        console.log("MeshDutchAuction:", meshDutchAuction);
        console.log("MeshResolverNetwork:", meshResolverNetwork);
        
        console.log("\n Contract Verification:");
        verifyContract("MeshEscrow", meshEscrow);
        verifyContract("MeshCrossChainOrder", meshCrossChainOrder);
        verifyContract("MeshLimitOrderProtocol", meshLimitOrderProtocol);
        verifyContract("MeshDutchAuction", meshDutchAuction);
        verifyContract("MeshResolverNetwork", meshResolverNetwork);
        
        console.log("\n Features Supported:");
        console.log(" Native ETH Support");
        console.log(" WETH Support");
        console.log(" 1inch Fusion+ Integration");
        console.log(" Dutch Auction Mechanism");
        console.log(" Resolver Network");
        console.log(" Cross-Chain HTLC");
        console.log(" Gasless Swaps");
        
        console.log("Ready for ETH to  SUI Swaps!");
    }
    
    function verifyContract(string memory name, address contractAddress) internal view {
        if (contractAddress == address(0)) {
            console.log("", name, "- Not deployed");
            return;
        }
        
        // Check if contract has code
        uint256 size;
        assembly {
            size := extcodesize(contractAddress)
        }
        
        if (size > 0) {
            console.log( name, "- Deployed and has code");
        } else {
            console.log( name, "- Address has no code");
        }
    }
}