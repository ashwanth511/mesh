// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {EscrowFactory} from "../src/EscrowFactory.sol";
import {FusionResolver} from "../src/FusionResolver.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy EscrowFactory
        console2.log("Deploying EscrowFactory...");
        EscrowFactory factory = new EscrowFactory();
        console2.log("EscrowFactory deployed at:", address(factory));
        console2.log("EscrowSrc deployed at:", address(factory.escrowSrc()));
        console2.log("EscrowDst deployed at:", address(factory.escrowDst()));

        // Deploy FusionResolver
        console2.log("Deploying FusionResolver...");
        FusionResolver resolver = new FusionResolver(payable(address(factory)));
        console2.log("FusionResolver deployed at:", address(resolver));



        vm.stopBroadcast();

        console2.log("Deployment completed successfully!");
        console2.log("Factory:", address(factory));
        console2.log("Resolver:", address(resolver));
    }
} 