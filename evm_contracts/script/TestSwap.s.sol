// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {IFusionPlus} from "../src/IFusionPlus.sol";
import {FusionResolver} from "../src/FusionResolver.sol";
import {EscrowFactory} from "../src/EscrowFactory.sol";

contract TestSwapScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get deployed contract addresses (replace with actual addresses after deployment)
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address resolverAddress = vm.envAddress("RESOLVER_ADDRESS");
        
        EscrowFactory factory = EscrowFactory(factoryAddress);
        FusionResolver resolver = FusionResolver(resolverAddress);

        // Test parameters for ETH → SUI swap
        uint256 swapAmount = 0.001 ether; // ~2 USDC worth of ETH
        uint256 safetyDeposit = 0.0001 ether;
        bytes32 secret = keccak256("test_secret_123");
        bytes32 hashlock = keccak256(abi.encodePacked(secret));

        // Create timelocks (100-300 seconds for testing)
        IFusionPlus.Timelocks memory timelocks = IFusionPlus.Timelocks({
            srcWithdrawal: 100,
            srcPublicWithdrawal: 200,
            srcCancellation: 300,
            srcPublicCancellation: 400,
            dstWithdrawal: 100,
            dstPublicWithdrawal: 200,
            dstCancellation: 300
        });

        // Create fee config
        IFusionPlus.FeeConfig memory feeConfig = IFusionPlus.FeeConfig({
            protocolFee: 10, // 0.01%
            integratorFee: 5, // 0.005%
            surplusPercentage: 50,
            maxCancellationPremium: 0.0001 ether
        });

        // Create order config
        IFusionPlus.OrderConfig memory orderConfig = IFusionPlus.OrderConfig({
            id: 1,
            srcAmount: swapAmount,
            minDstAmount: swapAmount * 95 / 100, // 5% slippage
            estimatedDstAmount: swapAmount,
            expirationTime: block.timestamp + 3600, // 1 hour
            srcAssetIsNative: true, // ETH is native
            dstAssetIsNative: true, // SUI is native
            fee: feeConfig,
            cancellationAuctionDuration: 300
        });

        // Create immutables
        IFusionPlus.Immutables memory immutables = IFusionPlus.Immutables({
            maker: msg.sender, // You are the maker
            taker: msg.sender, // You are also the taker (for testing)
            token: address(0), // Native ETH
            amount: swapAmount,
            hashlock: hashlock,
            timelocks: timelocks,
            safetyDeposit: safetyDeposit,
            deployedAt: 0
        });

        console2.log("=== ETH to SUI SWAP TEST ===");
        console2.log("Swap Amount:", swapAmount);
        console2.log("Safety Deposit:", safetyDeposit);
        console2.log("Hashlock:", vm.toString(hashlock));
        console2.log("Secret:", vm.toString(secret));

        // Step 1: Initiate ETH → SUI swap
        console2.log("\n1. Initiating ETH to SUI swap...");
        resolver.initiateEthereumToSuiSwap{value: swapAmount + safetyDeposit}(
            orderConfig,
            immutables
        );

        // Get order hash
        bytes32 orderHash = factory.computeOrderHash(orderConfig, immutables);
        console2.log("Order Hash:", vm.toString(orderHash));

        // Step 2: Check swap status
        console2.log("\n2. Checking swap status...");
        FusionResolver.CrossChainSwap memory swap = resolver.getSwap(orderHash);
        console2.log("Swap created at:", swap.createdAt);
        console2.log("Is Ethereum to Sui:", swap.isEthereumToSui);
        console2.log("Is completed:", swap.isCompleted);

        // Step 3: Simulate Sui escrow creation (in real scenario, this would be done on Sui)
        console2.log("\n3. Setting Sui escrow address (simulation)...");
        address suiEscrow = address(0x1234567890123456789012345678901234567890);
        resolver.setSuiEscrow(orderHash, suiEscrow);

        // Step 4: Complete the swap by revealing the secret
        console2.log("\n4. Completing swap by revealing secret...");
        resolver.completeSwap(orderHash, secret);

        // Step 5: Final status check
        console2.log("\n5. Final status check...");
        swap = resolver.getSwap(orderHash);
        console2.log("Is completed:", swap.isCompleted);
        console2.log("Sui escrow:", swap.suiEscrow);

        console2.log("\n=== SWAP TEST COMPLETED ===");

        vm.stopBroadcast();
    }
} 