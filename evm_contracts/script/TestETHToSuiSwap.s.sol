// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MeshEscrow.sol";
import "../src/core/MeshCrossChainOrder.sol";
import "../src/MeshLimitOrderProtocol.sol";
import "../src/core/MeshDutchAuction.sol";
import "../src/core/MeshResolverNetwork.sol";

/**
 * @title TestETHToSuiSwap
 * @dev Complete test script for ETH to SUI cross-chain swap
 */
contract TestETHToSuiSwapScript is Script {
    // Contract addresses (update these with your deployed addresses)
    address constant MESH_ESCROW = address(0); // UPDATE THIS
    address constant MESH_CROSS_CHAIN_ORDER = address(0); // UPDATE THIS
    address constant MESH_LIMIT_ORDER_PROTOCOL = address(0); // UPDATE THIS
    address constant MESH_DUTCH_AUCTION = address(0); // UPDATE THIS
    address constant MESH_RESOLVER_NETWORK = address(0); // UPDATE THIS
    address constant WETH_SEPOLIA = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    
    // Test parameters
    uint256 constant ETH_AMOUNT = 0.01 ether; // 0.01 ETH
    uint256 constant SUI_AMOUNT = 10 * 1e9; // 10 SUI (1e9 = 1 SUI)
    string constant SUI_ORDER_HASH = "test_sui_order_123";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log(" Testing ETH to SUI Cross-Chain Swap");
        console.log("Deployer:", deployer);
        console.log("ETH Balance:", deployer.balance);
        
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
        
        // Create auction config
        IMeshCrossChainOrder.DutchAuctionConfig memory auctionConfig = IMeshCrossChainOrder.DutchAuctionConfig({
            auctionStartTime: block.timestamp + 300, // Start in 5 minutes
            auctionEndTime: block.timestamp + 3900,  // End in 65 minutes
            startRate: 6 * 1e18, // 6:1 starting rate
            endRate: 1 * 1e18    // 1:1 ending rate
        });
        
        // Create cross-chain config
        IMeshCrossChainOrder.CrossChainConfig memory crossChainConfig = IMeshCrossChainOrder.CrossChainConfig({
            suiOrderHash: SUI_ORDER_HASH,
            timelockDuration: 3600, // 1 hour
            destinationAddress: "0x1234567890123456789012345678901234567890",
            secretHash: keccak256(abi.encodePacked("test_secret"))
        });
        
        try crossChainOrder.createCrossChainOrderWithEth{value: ETH_AMOUNT}(
            SUI_AMOUNT,
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
        try weth.deposit{value: ETH_AMOUNT}() {
            console.log(" Deposited ETH to WETH");
            
            // Approve WETH spending
            weth.approve(MESH_CROSS_CHAIN_ORDER, ETH_AMOUNT);
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
                ETH_AMOUNT,
                SUI_AMOUNT,
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
        
        try escrow.createEscrowWithEth{value: ETH_AMOUNT}(
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

