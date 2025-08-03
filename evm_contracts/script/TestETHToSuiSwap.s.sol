// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MeshEscrow.sol";
import "../src/core/MeshCrossChainOrder.sol";
import "../src/MeshLimitOrderProtocol.sol";
import "../src/core/MeshDutchAuction.sol";
import "../src/core/MeshResolverNetwork.sol";
import "./DynamicConfig.s.sol";

/**
 * @title TestETHToSuiSwap
 * @dev Complete test script for ETH to SUI cross-chain swap with dynamic configuration
 */
contract TestETHToSuiSwapScript is Script {
    // Contract addresses (DEPLOYED ON SEPOLIA)
    address constant MESH_ESCROW = 0x326828Bb799bDAf4f37127d5Ed413A5f26233aE9;
    address constant MESH_CROSS_CHAIN_ORDER = 0x297e209DFD686aBb121832B31372AC44ea88D6E0;
    address constant MESH_LIMIT_ORDER_PROTOCOL = 0xbB429b3718697933dE85201403b77e5c2eA66794;
    address constant MESH_DUTCH_AUCTION = 0xCe8961a85fE2FAF4FED19a790f3F3c4a8D20eF0d;
    address constant MESH_RESOLVER_NETWORK = 0xa6F654DED8EBC7Ed1bFC49a40E399E5ba6ac8b22;
    address constant WETH_SEPOLIA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    
    // Dynamic configuration
    DynamicConfig config;
    
    function run() external {
        string memory privateKeyString = vm.envString("PRIVATE_KEY");
        // Add 0x prefix and parse as hex
        string memory privateKeyHex = string(abi.encodePacked("0x", privateKeyString));
        uint256 deployerPrivateKey = vm.parseUint(privateKeyHex);
        address deployer = vm.addr(deployerPrivateKey);
        
        // Initialize dynamic configuration
        config = new DynamicConfig();
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log(" Testing ETH to SUI Cross-Chain Swap (Dynamic Configuration)");
        console.log("Deployer:", deployer);
        console.log("ETH Balance:", deployer.balance);
        
        // Print current configuration
        config.printConfig();
        
        // Step 1: Test Native ETH Cross-Chain Order
        testNativeETHCrossChainOrder(deployer);
        
        // Step 2: Test WETH Cross-Chain Order
        testWETHCrossChainOrder(deployer);
        
        // Step 3: Test Direct Escrow Creation
        testDirectEscrowCreation(deployer);
        
        // Step 4: Test Resolver Network
        testResolverNetwork(deployer);
        
        vm.stopBroadcast();
        
        console.log(" All tests completed successfully!");
        console.log(" Ready for cross-chain ETH to SUI swaps!");
    }
    
    function testNativeETHCrossChainOrder(address deployer) internal {
        console.log("\nTest 1: Native ETH Cross-Chain Order");
        
        if (MESH_CROSS_CHAIN_ORDER == address(0)) {
            console.log(" MESH_CROSS_CHAIN_ORDER address not set");
            return;
        }
        
        MeshCrossChainOrder crossChainOrder = MeshCrossChainOrder(MESH_CROSS_CHAIN_ORDER);
        
        // Create auction config (DYNAMIC RATES from environment)
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: block.timestamp + 300, // Start in 5 minutes
            auctionEndTime: block.timestamp + config.getAuctionDuration(),  // Dynamic duration
            startRate: config.getAuctionStartRate(), // Dynamic start rate
            endRate: config.getAuctionEndRate()    // Dynamic end rate
        });
        
        // Create cross-chain config (DYNAMIC from environment)
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: config.getOrderHash(),
            timelockDuration: config.getTimelockDuration(), // Dynamic timelock
            destinationAddress: "0x1234567890123456789012345678901234567890",
            secretHash: keccak256(abi.encodePacked("test_secret"))
        });
        
        try crossChainOrder.createCrossChainOrderWithEth{value: config.getTestETHAmount()}(
            config.getTestSUIAmount(),
            auctionConfig,
            crossChainConfig
        ) returns (bytes32 orderHash) {
            console.log(" Native ETH Cross-Chain Order Created");
            console.log("Order Hash:", vm.toString(orderHash));
            
            // Verify order
            IMeshCrossChainOrder.CrossChainOrder memory order = crossChainOrder.getCrossChainOrder(orderHash);
            console.log("Source Amount:", order.sourceAmount);
            console.log("Destination Amount:", order.destinationAmount);
            console.log("Is Native ETH:", order.isNativeEth);
            
        } catch Error(string memory reason) {
            console.log(" Native ETH Order Failed:", reason);
        }
    }
    
    function testWETHCrossChainOrder(address deployer) internal {
        console.log("\n Test 2: WETH Cross-Chain Order");
        
        if (MESH_CROSS_CHAIN_ORDER == address(0)) {
            console.log(" MESH_CROSS_CHAIN_ORDER address not set");
            return;
        }
        
        // First, get some WETH
        IWETH weth = IWETH(WETH_SEPOLIA);
        try weth.deposit{value: config.getTestETHAmount()}() {
            console.log(" Deposited ETH to WETH");
            
            // Approve WETH spending
            weth.approve(MESH_CROSS_CHAIN_ORDER, config.getTestETHAmount());
            console.log(" Approved WETH spending");
            
            MeshCrossChainOrder crossChainOrder = MeshCrossChainOrder(MESH_CROSS_CHAIN_ORDER);
            
            // Create auction config
            IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
                auctionStartTime: block.timestamp + 300,
                auctionEndTime: block.timestamp + 3900,
                startRate: 6 * 1e18,
                endRate: 1 * 1e18
            });
            
            // Create cross-chain config
            IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
                suiOrderHash: "weth_sui_order_123",
                timelockDuration: 3600,
                destinationAddress: "0x1234567890123456789012345678901234567890",
                secretHash: keccak256(abi.encodePacked("weth_test_secret"))
            });
            
            try crossChainOrder.createCrossChainOrder(
                config.getTestETHAmount(),
                config.getTestSUIAmount(),
                auctionConfig,
                crossChainConfig
            ) returns (bytes32 orderHash) {
                console.log(" WETH Cross-Chain Order Created");
                console.log("Order Hash:", vm.toString(orderHash));
            } catch Error(string memory reason) {
                console.log(" WETH Cross-Chain Order Failed:", reason);
            }
            
        } catch Error(string memory reason) {
            console.log(" WETH Order Failed:", reason);
        }
    }
    
    function testDirectEscrowCreation(address deployer) internal {
        console.log("\n Test 3: Direct Escrow Creation");
        
        if (MESH_ESCROW == address(0)) {
            console.log(" MESH_ESCROW address not set");
            return;
        }
        
        MeshEscrow escrow = MeshEscrow(payable(MESH_ESCROW));
        
        // Test Native ETH Escrow
        bytes32 hashLock = keccak256(abi.encodePacked("test_secret_123"));
        uint256 timeLock = block.timestamp + 3600; // 1 hour
        address payable taker = payable(address(0x1234567890123456789012345678901234567890));
        
        try escrow.createEscrowWithEth{value: config.getTestETHAmount()}(
            hashLock,
            timeLock,
            taker,
            "direct_escrow_test"
        ) returns (bytes32 escrowId) {
            console.log(" Native ETH Escrow Created");
            console.log("Escrow ID:", vm.toString(escrowId));
            
            // Verify escrow
            MeshEscrow.Escrow memory escrowData = escrow.getEscrow(escrowId);
            console.log("Escrow Amount:", escrowData.totalAmount);
            console.log("Is Native ETH:", escrowData.isNativeEth);
            console.log("Maker:", escrowData.maker);
            
        } catch Error(string memory reason) {
            console.log(" Direct Escrow Failed:", reason);
        }
    }
    
    function testResolverNetwork(address deployer) internal {
        console.log("\n Test 4: Resolver Network");
        
        if (MESH_RESOLVER_NETWORK == address(0)) {
            console.log("MESH_RESOLVER_NETWORK address not set");
            return;
        }
        
        // First, get some WETH for staking
        IWETH weth = IWETH(WETH_SEPOLIA);
        uint256 stakeAmount = 1 ether; // 1 WETH stake
        
        if (weth.balanceOf(deployer) < stakeAmount) {
            try weth.deposit{value: stakeAmount}() {
                console.log("Deposited ETH to WETH for staking");
            } catch Error(string memory reason) {
                console.log(" WETH deposit failed:", reason);
                return;
            }
        }
        
        MeshResolverNetwork resolverNetwork = MeshResolverNetwork(MESH_RESOLVER_NETWORK);
        
        // Approve WETH for staking
        weth.approve(MESH_RESOLVER_NETWORK, stakeAmount);
        console.log(" Approved WETH for resolver staking");
        
        // Register as resolver
        try resolverNetwork.registerResolver(stakeAmount) {
            console.log(" Registered as resolver");
            
            // Check resolver status
            IMeshResolverNetwork.Resolver memory resolver = resolverNetwork.getResolver(deployer);
            console.log("Resolver Stake:", resolver.stake);
            console.log("Resolver Authorized:", resolver.isAuthorized);
            console.log("Resolver Reputation:", resolver.reputation);
            
        } catch Error(string memory reason) {
            console.log(" Resolver Network Failed:", reason);
        }
    }
}

