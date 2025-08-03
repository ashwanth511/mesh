const { ethers } = require('ethers');
require('dotenv').config();

// Contract ABIs
const MESH_ESCROW_ABI = [
  "function fillEscrow(bytes32 escrowId, bytes32 secret) external",
  "function getEscrow(bytes32 escrowId) external view returns (address, address, uint256, uint256, bytes32, uint256, bool, bool, bool, uint256, string memory, bytes32)",
  "event EscrowFilled(bytes32 indexed escrowId, address indexed resolver, bytes32 secret, uint256 amount, bool isNativeEth, string suiOrderHash)"
];

async function completeETHToSuiSwap() {
  try {
    console.log('🔄 Completing ETH to SUI Cross-Chain Swap...');
    
    // Setup provider and wallet
    const provider = new ethers.JsonRpcProvider(process.env.ETH_RPC_URL);
    const wallet = new ethers.Wallet(process.env.ETH_PRIVATE_KEY, provider);
    
    console.log('📡 Connected to Ethereum network');
    console.log('👤 Wallet address:', wallet.address);
    
    // Contract instance
    const meshEscrow = new ethers.Contract(process.env.MESH_ESCROW_ADDRESS, MESH_ESCROW_ABI, wallet);
    
    // Your escrow details from the previous test
    const escrowId = '0xf448b05c1d1a3ae02914d6309daec62fd316883d2fc2e964f01ee1d2520a45bb';
    const secret = '0x190d6c4503780699a0654f48300a1d74e962f7b0c5e76f1f2533a6df85dddf5d'; // This is the hash, we need the original secret
    
    console.log('📋 Escrow Details:');
    console.log('   Escrow ID:', escrowId);
    console.log('   Hash Lock:', secret);
    
    // Check escrow status
    console.log('\n🔍 Checking escrow status...');
    const escrowInfo = await meshEscrow.getEscrow(escrowId);
    console.log('   Maker:', escrowInfo[0]);
    console.log('   Taker:', escrowInfo[1]);
    console.log('   Total Amount:', ethers.formatEther(escrowInfo[2]), 'ETH');
    console.log('   Remaining Amount:', ethers.formatEther(escrowInfo[3]), 'ETH');
    console.log('   Hash Lock:', escrowInfo[4]);
    console.log('   Timelock:', new Date(Number(escrowInfo[5]) * 1000).toLocaleString());
    console.log('   Is Completed:', escrowInfo[6]);
    console.log('   Is Refunded:', escrowInfo[7]);
    console.log('   Is Native ETH:', escrowInfo[8]);
    
    if (escrowInfo[6]) {
      console.log('✅ Escrow already completed!');
      return;
    }
    
    // To complete the swap, we need the original secret that was used to create the hash lock
    // In a real scenario, this would be shared between the parties
    console.log('\n🔑 To complete the swap:');
    console.log('   1. You need the original secret that created the hash lock');
    console.log('   2. Create matching escrow on Sui with same hash lock');
    console.log('   3. Use the secret to claim both escrows');
    
    // For demo purposes, let's show how to claim if we had the secret
    console.log('\n📝 Example claim transaction (if you had the secret):');
    console.log('   const originalSecret = "your-original-secret-here";');
    console.log('   const tx = await meshEscrow.fillEscrow(escrowId, originalSecret);');
    
    console.log('\n🎯 Next Steps:');
    console.log('   1. Create matching Sui escrow with hash lock:', secret);
    console.log('   2. Share the original secret between parties');
    console.log('   3. Claim both escrows atomically');
    console.log('   4. Complete the cross-chain swap!');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Run the completion script
completeETHToSuiSwap(); 