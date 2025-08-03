const { ethers } = require('ethers');
require('dotenv').config();

// Contract ABIs (simplified for testing)
const MESH_ESCROW_ABI = [
  "function createEscrow(bytes32 orderHash, uint256 amount, uint256 timelock) external payable",
  "function claim(bytes32 orderHash, bytes32 secret) external",
  "function refund(bytes32 orderHash) external",
  "function getEscrow(bytes32 orderHash) external view returns (address, uint256, uint256, bool, bool)"
];

const MESH_CROSS_CHAIN_ORDER_ABI = [
  "function createCrossChainOrderWithEth(uint256 destinationAmount, tuple(uint256 auctionStartTime, uint256 auctionEndTime, uint256 startRate, uint256 endRate) auctionConfig, tuple(bytes32 suiOrderHash, uint256 timelockDuration) crossChainConfig) external payable returns (bytes32)",
  "event CrossChainOrderCreated(bytes32 indexed orderHash, bytes32 indexed limitOrderHash, address indexed user, uint256 sourceAmount, uint256 destinationAmount, tuple(uint256 auctionStartTime, uint256 auctionEndTime, uint256 startRate, uint256 endRate) auctionConfig, tuple(bytes32 suiOrderHash, uint256 timelockDuration) crossChainConfig)"
];

async function testETHToSuiSwap() {
  try {
    console.log('🚀 Testing ETH to SUI Cross-Chain Swap...');
    
    // Setup provider and wallet
    const provider = new ethers.JsonRpcProvider(process.env.ETH_RPC_URL);
    const wallet = new ethers.Wallet(process.env.ETH_PRIVATE_KEY, provider);
    
    console.log('📡 Connected to Ethereum network');
    console.log('👤 Wallet address:', wallet.address);
    
    // Get balances
    const ethBalance = await provider.getBalance(wallet.address);
    console.log('💰 ETH Balance:', ethers.formatEther(ethBalance), 'ETH');
    
    // Contract instances
    const meshEscrow = new ethers.Contract(process.env.MESH_ESCROW_ADDRESS, MESH_ESCROW_ABI, wallet);
    const meshCrossChainOrder = new ethers.Contract(process.env.MESH_CROSS_CHAIN_ORDER_ADDRESS, MESH_CROSS_CHAIN_ORDER_ABI, wallet);
    
    console.log('📋 Contract addresses:');
    console.log('   MeshEscrow:', process.env.MESH_ESCROW_ADDRESS);
    console.log('   MeshCrossChainOrder:', process.env.MESH_CROSS_CHAIN_ORDER_ADDRESS);
    
    // Test parameters
    const testAmount = ethers.parseEther('0.002'); // 0.002 ETH
    const destinationAmount = ethers.parseEther('0.001'); // 0.001 SUI (equivalent)
    
    console.log('\n🎯 Test Parameters:');
    console.log('   Source Amount (ETH):', ethers.formatEther(testAmount));
    console.log('   Destination Amount (SUI):', ethers.formatEther(destinationAmount));
    
    // Check if we have enough ETH
    if (ethBalance < testAmount) {
      console.log('❌ Insufficient ETH balance for test');
      return;
    }
    
    // Create cross-chain order
    console.log('\n📝 Creating cross-chain order...');
    
    const currentTime = Math.floor(Date.now() / 1000);
    const auctionConfig = {
      auctionStartTime: currentTime + 60, // Start in 1 minute
      auctionEndTime: currentTime + 3600, // End in 1 hour
      startRate: ethers.parseEther('6.0'), // 6x rate
      endRate: ethers.parseEther('1.0')   // 1x rate
    };
    
    const crossChainConfig = {
      suiOrderHash: ethers.keccak256(ethers.toUtf8Bytes('test-sui-order')), // Mock Sui order hash
      timelockDuration: 3600 // 1 hour
    };
    
    const tx = await meshCrossChainOrder.createCrossChainOrderWithEth(
      destinationAmount,
      auctionConfig,
      crossChainConfig,
      { value: testAmount, gasLimit: 500000 }
    );
    
    console.log('⏳ Transaction sent:', tx.hash);
    console.log('⏳ Waiting for confirmation...');
    
    const receipt = await tx.wait();
    console.log('✅ Transaction confirmed in block:', receipt.blockNumber);
    
    // Parse events
    const event = receipt.logs.find(log => {
      try {
        const parsed = meshCrossChainOrder.interface.parseLog(log);
        return parsed.name === 'CrossChainOrderCreated';
      } catch {
        return false;
      }
    });
    
    if (event) {
      const parsed = meshCrossChainOrder.interface.parseLog(event);
      const orderHash = parsed.args.orderHash;
      console.log('🎉 Cross-chain order created successfully!');
      console.log('   Order Hash:', orderHash);
      console.log('   Limit Order Hash:', parsed.args.limitOrderHash);
      console.log('   User:', parsed.args.user);
      console.log('   Source Amount:', ethers.formatEther(parsed.args.sourceAmount));
      console.log('   Destination Amount:', ethers.formatEther(parsed.args.destinationAmount));
      
      // Check escrow status
      console.log('\n🔍 Checking escrow status...');
      const escrowInfo = await meshEscrow.getEscrow(orderHash);
      console.log('   Escrow exists:', escrowInfo[3]); // isCreated
      console.log('   Escrow claimed:', escrowInfo[4]); // isClaimed
      
    } else {
      console.log('⚠️  Order created but event not found');
    }
    
    // Final balance check
    const finalBalance = await provider.getBalance(wallet.address);
    console.log('\n💰 Final ETH Balance:', ethers.formatEther(finalBalance), 'ETH');
    console.log('💸 ETH spent:', ethers.formatEther(ethBalance - finalBalance), 'ETH');
    
    console.log('\n✅ Test completed successfully!');
    console.log('📊 Next steps:');
    console.log('   1. Start the relayer to process the order');
    console.log('   2. Check your Sui wallet for incoming SUI');
    console.log('   3. Monitor the order status');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.transaction) {
      console.error('   Transaction hash:', error.transaction.hash);
    }
  }
}

// Run the test
testETHToSuiSwap(); 