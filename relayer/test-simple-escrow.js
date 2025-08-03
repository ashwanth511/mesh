const { ethers } = require('ethers');
require('dotenv').config();

// Simple Escrow ABI
const MESH_ESCROW_ABI = [
  "function createEscrowWithEth(bytes32 hashLock, uint256 timeLock, address payable taker, string calldata suiOrderHash) external payable returns (bytes32)",
  "function fillEscrow(bytes32 escrowId, bytes32 secret) external",
  "function refundEscrow(bytes32 escrowId) external",
  "function getEscrow(bytes32 escrowId) external view returns (address, address, uint256, uint256, bytes32, uint256, bool, bool, bool, uint256, string memory, bytes32)",
  "event EscrowCreated(bytes32 indexed escrowId, address indexed maker, address indexed taker, uint256 amount, bytes32 hashLock, uint256 timeLock, bool isNativeEth, string suiOrderHash)"
];

async function testSimpleEscrow() {
  try {
    console.log('🚀 Testing Simple ETH Escrow (Direct HTLC)...');
    
    // Setup provider and wallet
    const provider = new ethers.JsonRpcProvider(process.env.ETH_RPC_URL);
    const wallet = new ethers.Wallet(process.env.ETH_PRIVATE_KEY, provider);
    
    console.log('📡 Connected to Ethereum network');
    console.log('👤 Wallet address:', wallet.address);
    
    // Get balances
    const ethBalance = await provider.getBalance(wallet.address);
    console.log('💰 ETH Balance:', ethers.formatEther(ethBalance), 'ETH');
    
    // Contract instance
    const meshEscrow = new ethers.Contract(process.env.MESH_ESCROW_ADDRESS, MESH_ESCROW_ABI, wallet);
    
    console.log('📋 Contract address:');
    console.log('   MeshEscrow:', process.env.MESH_ESCROW_ADDRESS);
    
    // Test parameters
    const testAmount = ethers.parseEther('0.002'); // 0.002 ETH
    const secret = ethers.keccak256(ethers.toUtf8Bytes('my-secret-' + Date.now()));
    const hashLock = ethers.keccak256(secret); // Hash of the secret
    const timeLock = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
    const taker = ethers.ZeroAddress; // Open to anyone
    const suiOrderHash = 'test-sui-order-' + Date.now();
    
    console.log('\n🎯 Test Parameters:');
    console.log('   Amount (ETH):', ethers.formatEther(testAmount));
    console.log('   Secret:', secret);
    console.log('   Hash Lock:', hashLock);
    console.log('   Timelock:', new Date(timeLock * 1000).toLocaleString());
    console.log('   Taker:', taker === ethers.ZeroAddress ? 'Anyone can claim' : taker);
    console.log('   Sui Order Hash:', suiOrderHash);
    
    // Check if we have enough ETH
    if (ethBalance < testAmount) {
      console.log('❌ Insufficient ETH balance for test');
      return;
    }
    
    // Create escrow
    console.log('\n📝 Creating escrow...');
    
    const tx = await meshEscrow.createEscrowWithEth(
      hashLock,
      timeLock,
      taker,
      suiOrderHash,
      { value: testAmount, gasLimit: 300000 }
    );
    
    console.log('⏳ Transaction sent:', tx.hash);
    console.log('⏳ Waiting for confirmation...');
    
    const receipt = await tx.wait();
    console.log('✅ Transaction confirmed in block:', receipt.blockNumber);
    
    // Parse events
    const event = receipt.logs.find(log => {
      try {
        const parsed = meshEscrow.interface.parseLog(log);
        return parsed.name === 'EscrowCreated';
      } catch {
        return false;
      }
    });
    
    let escrowId;
    if (event) {
      const parsed = meshEscrow.interface.parseLog(event);
      escrowId = parsed.args.escrowId;
      console.log('🎉 Escrow created successfully!');
      console.log('   Escrow ID:', escrowId);
      console.log('   Maker:', parsed.args.maker);
      console.log('   Taker:', parsed.args.taker);
      console.log('   Amount:', ethers.formatEther(parsed.args.amount), 'ETH');
      console.log('   Hash Lock:', parsed.args.hashLock);
      console.log('   Timelock:', new Date(Number(parsed.args.timeLock) * 1000).toLocaleString());
      console.log('   Is Native ETH:', parsed.args.isNativeEth);
      console.log('   Sui Order Hash:', parsed.args.suiOrderHash);
    } else {
      console.log('⚠️  Escrow created but event not found');
      // Try to get escrowId from transaction logs
      console.log('   Receipt logs:', receipt.logs.length);
    }
    
    // Check escrow status (if we have escrowId)
    if (escrowId) {
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
      console.log('   Sui Order Hash:', escrowInfo[10]);
    }
    
    // Final balance check
    const finalBalance = await provider.getBalance(wallet.address);
    console.log('\n💰 Final ETH Balance:', ethers.formatEther(finalBalance), 'ETH');
    console.log('💸 ETH spent:', ethers.formatEther(ethBalance - finalBalance), 'ETH');
    
    console.log('\n✅ Simple escrow test completed successfully!');
    console.log('📊 This is how unite-sui does swaps - direct HTLC!');
    console.log('🔄 Now you can:');
    console.log('   1. Create matching escrow on Sui side');
    console.log('   2. Exchange secrets to claim both escrows');
    console.log('   3. Complete the cross-chain swap');
    console.log('\n🔑 To claim this escrow, use secret:', secret);
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    if (error.transaction) {
      console.error('   Transaction hash:', error.transaction.hash);
    }
  }
}

// Run the test
testSimpleEscrow();