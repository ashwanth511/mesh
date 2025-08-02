// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {SuiResolver} from "../src/SuiResolver.sol";
import {IEscrowFactory} from "cross-chain-swap/interfaces/IEscrowFactory.sol";
import {IOrderMixin} from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";

/**
 * @title DeploySui - Deployment script for gas-free Ethereum-Sui swap resolver
 * @dev Deploys SuiResolver that works with 1inch Fusion+ pattern
 * @dev Users create orders off-chain, resolvers call deploySrc/deployDst to fill them
 */
contract DeploySui is Script {
    // TODO: Set these to actual 1inch contract addresses on your target network
    address constant ESCROW_FACTORY_ADDRESS = 0x1111111111111111111111111111111111111111;
    address constant LIMIT_ORDER_PROTOCOL_ADDRESS = 0x2222222222222222222222222222222222222222;
    address constant RELAYER_ADDRESS = 0x3333333333333333333333333333333333333333;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying gas-free Ethereum-Sui swap resolver...");
        console.log("Deployer:", deployer);
        console.log("Escrow Factory:", ESCROW_FACTORY_ADDRESS);
        console.log("Limit Order Protocol:", LIMIT_ORDER_PROTOCOL_ADDRESS);

        // Deploy SuiResolver (this IS the resolver!)
        console.log("Deploying SuiResolver...");
        SuiResolver suiResolver = new SuiResolver(
            IEscrowFactory(ESCROW_FACTORY_ADDRESS),
            IOrderMixin(LIMIT_ORDER_PROTOCOL_ADDRESS),
            deployer // initial owner
        );

        console.log("SuiResolver deployed at:", address(suiResolver));

        // Set the relayer
        suiResolver.setRelayer(RELAYER_ADDRESS);
        console.log("Relayer set to:", RELAYER_ADDRESS);

        vm.stopBroadcast();

        console.log("\nDeployment completed successfully!");
        console.log("=== Contract Addresses ===");
        console.log("SuiResolver:", address(suiResolver));
        console.log("Relayer:", RELAYER_ADDRESS);
        console.log("Escrow Factory:", ESCROW_FACTORY_ADDRESS);
        console.log("Limit Order Protocol:", LIMIT_ORDER_PROTOCOL_ADDRESS);
        
        console.log("\n=== Contract Owner ===");
        console.log("SuiResolver Owner:", suiResolver.owner());
        
        console.log("\n=== How it works ===");
        console.log("1. User creates order off-chain (no gas needed)");
        console.log("2. Resolver calls SuiResolver.deploySrc() to fill order (RESOLVER PAYS GAS)");
        console.log("3. Relayer coordinates cross-chain completion");
        console.log("4. User gets tokens without paying gas fees!");
        
        console.log("\n=== Next Steps ===");
        console.log("1. Update contract addresses with real 1inch addresses");
        console.log("2. Deploy to testnet/mainnet");
        console.log("3. Set up relayer service");
        console.log("4. Test gas-free swaps!");
    }
} 