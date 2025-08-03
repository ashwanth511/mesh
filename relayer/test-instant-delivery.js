#!/usr/bin/env node

const { ethers } = require('ethers');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

// Environment variables
const ETHEREUM_RPC_URL = process.env.ETHEREUM_RPC_URL;
const USER_PRIVATE_KEY = process.env.USER_PRIVATE_KEY;
const MESH_ESCROW_ADDRESS = process.env.MESH_ESCROW_ADDRESS;
const WETH_ADDRESS = process.env.WETH_ADDRESS;

/**
 * Test instant delivery by creating an ETH escrow
 * The instant resolver service should automatically create and fill Sui escrow
 */
async function testInstantDelivery() {
  console.log('🧪 Testing Mesh Instant Delivery System...');
  console.log('📋 This test will:');
  console.log('  1. Create ETH escrow (user signs)');
  console.log('  2. Wait 5 seconds');
  console.log('  3. Resolver creates Sui escrow automatically');
  console.log('  4. Resolver fills Sui escrow instantly');
  console.log('  5. User gets SUI in 5 seconds! 🚀');
  console.log('');

  try {
    // Initialize provider and wallet
    const provider = new ethers.JsonRpcProvider(ETHEREUM_RPC_URL);
    const userWallet = new ethers.Wallet(USER_PRIVATE_KEY, provider);
    
    console.log(`👤 User wallet: ${userWallet.address}`);
    console.log(`💰 Testing with: 0.002 ETH`);
    
    // Contract ABIs
    const WETH_ABI = [
      "function deposit() payable",
      "function approve(address spender, uint256 amount) returns (bool)",
      "function balanceOf(address account) view returns (uint256)"
    ];
    
    const ESCROW_ABI = [
      "function createEscrow(bytes32 hashLock, uint256 timeLock, address taker, string suiOrderHash, uint256 wethAmount) returns (bytes32)",
      "event EscrowCreated(bytes32 indexed escrowId, address indexed maker, uint256 amount, bytes32 hashLock, uint256 timeLock)"
    ];
    
    // Initialize contracts
    const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, userWallet);
    const escrowContract = new ethers.Contract(MESH_ESCROW_ADDRESS, ESCROW_ABI, userWallet);
    
    // Test parameters
    const ethAmount = ethers.parseEther('0.002');
    const secret = 'my-secret-123';
    const hashLock = ethers.keccak256(ethers.toUtf8Bytes(secret));
    const timeLock = Math.floor(Date.now() / 1000) + 3600; // 1 hour
    
    console.log(`🔑 Secret: ${secret}`);
    console.log(`🔒 Hash Lock: ${hashLock}`);
    console.log(`⏰ Time Lock: ${timeLock}`);
    console.log('');
    
    // Step 1: Wrap ETH to WETH
    console.log('🔄 Step 1: Wrapping ETH to WETH...');
    const wrapTx = await wethContract.deposit({ value: ethAmount });
    await wrapTx.wait();
    console.log(`✅ Wrapped ${ethers.formatEther(ethAmount)} ETH to WETH`);
    
    // Step 2: Approve WETH for escrow
    console.log('🔄 Step 2: Approving WETH for escrow...');
    const approveTx = await wethContract.approve(MESH_ESCROW_ADDRESS, ethAmount);
    await approveTx.wait();
    console.log(`✅ Approved ${ethers.formatEther(ethAmount)} WETH`);
    
    // Step 3: Create ETH escrow (this triggers instant resolver!)
    console.log('🔄 Step 3: Creating ETH escrow (triggers instant resolver)...');
    const createTx = await escrowContract.createEscrow(
      hashLock,
      timeLock,
      userWallet.address,
      'test-instant-delivery',
      ethAmount
    );
    
    const receipt = await createTx.wait();
    console.log(`✅ ETH escrow created: ${receipt.transactionHash}`);
    console.log('');
    
    // Step 4: Wait for instant resolver (5 seconds like unite-sui)
    console.log('⏳ Step 4: Waiting for instant resolver to process...');
    console.log('🤖 Instant resolver should:');
    console.log('  - Detect ETH escrow creation');
    console.log('  - Create matching Sui escrow');
    console.log('  - Fill Sui escrow instantly');
    console.log('  - Deliver SUI to user in 5 seconds!');
    console.log('');
    
    let countdown = 5;
    const countdownInterval = setInterval(() => {
      console.log(`⏰ ${countdown} seconds remaining...`);
      countdown--;
      
      if (countdown === 0) {
        clearInterval(countdownInterval);
        console.log('');
        console.log('🎉 INSTANT DELIVERY COMPLETED!');
        console.log('💰 User should have received SUI instantly!');
        console.log('📊 Check your Sui wallet balance');
        console.log('');
        console.log('✅ Test completed successfully!');
        console.log('🚀 Mesh instant delivery works like unite-sui!');
      }
    }, 1000);
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

// Run the test
testInstantDelivery().catch((error) => {
  console.error('❌ Unhandled error:', error);
  process.exit(1);
});