// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {SuiResolver} from "../src/SuiResolver.sol";
import {IEscrowFactory} from "cross-chain-swap/interfaces/IEscrowFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deployment script for Sui Fusion+ integration
 * @dev Deploys the Sui resolver and configures it with the official 1inch contracts
 */
contract DeploySui is Script {
    // Configuration - Update these addresses for your deployment
    address public constant ESCROW_FACTORY_ADDRESS = 0x0000000000000000000000000000000000000000; // TODO: Set actual 1inch factory address
    address public constant ACCESS_TOKEN_ADDRESS = 0x0000000000000000000000000000000000000000; // TODO: Set actual access token address
    address public constant RELAYER_ADDRESS = 0x0000000000000000000000000000000000000000; // TODO: Set your relayer address

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log(" Deploying Sui Fusion plus contracts...");
        console.log(" Deployer:", deployer);
        console.log(" Deployer balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Sui Resolver
        console.log(" Deploying SuiResolver...");
        SuiResolver suiResolver = new SuiResolver(
            IEscrowFactory(ESCROW_FACTORY_ADDRESS),
            IERC20(ACCESS_TOKEN_ADDRESS)
        );

        console.log("SuiResolver deployed at:", address(suiResolver));

        // Set relayer address
        console.log("Setting relayer address...");
        suiResolver.setRelayer(RELAYER_ADDRESS);
        console.log("Relayer set to:", RELAYER_ADDRESS);

        vm.stopBroadcast();

        console.log("\n Deployment completed successfully!");
        console.log(" Contract Addresses:");
        console.log("   SuiResolver:", address(suiResolver));
        console.log("   EscrowFactory:", ESCROW_FACTORY_ADDRESS);
        console.log("   AccessToken:", ACCESS_TOKEN_ADDRESS);
        console.log("   Relayer:", RELAYER_ADDRESS);
        
        console.log("\n Next Steps:");
        console.log("   1. Update ESCROW_FACTORY_ADDRESS with actual 1inch factory");
        console.log("   2. Update ACCESS_TOKEN_ADDRESS with actual access token");
        console.log("   3. Update RELAYER_ADDRESS with your relayer address");
        console.log("   4. Run: forge script DeploySui --rpc-url <RPC_URL> --broadcast");
    }
} 