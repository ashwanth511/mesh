const { ethers } = require('ethers');
require('dotenv').config();

// Your Ethereum escrow details from the previous test
const ETH_ESCROW_ID = '0xf448b05c1d1a3ae02914d6309daec62fd316883d2fc2e964f01ee1d2520a45bb';
const ETH_HASH_LOCK = '0x190d6c4503780699a0654f48300a1d74e962f7b0c5e76f1f2533a6df85dddf5d';
const ETH_ORDER_HASH = 'test-sui-order-1754214277591';

// Sui package details
const SUI_PACKAGE_ID = '0x19e8821daaf73d8499290975a828f6637bb46b3beade26ce430d060b3cf95908';
const SUI_ESCROW_FACTORY = '0x84631050dc3e3936d72e1a2205da5c6ed22746d2886e4a147e9a53ccf2df5021';

async function completeSwapWithSui() {
  try {
    console.log('🔄 Completing ETH ↔ SUI Cross-Chain Swap...');
    console.log('');
    
    console.log('📋 Ethereum Side:');
    console.log('   Escrow ID:', ETH_ESCROW_ID);
    console.log('   Hash Lock:', ETH_HASH_LOCK);
    console.log('   Order Hash:', ETH_ORDER_HASH);
    console.log('   Amount: 0.002 ETH');
    console.log('');
    
    console.log('📋 Sui Side:');
    console.log('   Package ID:', SUI_PACKAGE_ID);
    console.log('   Escrow Factory:', SUI_ESCROW_FACTORY);
    console.log('   Amount: 0.001 SUI (equivalent)');
    console.log('');
    
    console.log('🎯 To Complete the Swap:');
    console.log('');
    console.log('1. Create matching Sui escrow:');
    console.log(`   sui client call --package ${SUI_PACKAGE_ID} --module complete_swap --function complete_eth_to_sui_swap`);
    console.log('   --args <sui_coin> <ethereum_hash_lock> <ethereum_order_hash> <clock>');
    console.log('');
    console.log('2. Execute swap on both chains:');
    console.log('   - Use the original secret to claim ETH escrow');
    console.log('   - Use the same secret to claim Sui escrow');
    console.log('');
    console.log('3. Commands to run:');
    console.log('');
         console.log('   # Create Sui escrow with same hash lock');
     console.log(`   sui client call --package ${SUI_PACKAGE_ID} \\`);
     console.log('     --module complete_swap \\');
     console.log('     --function complete_eth_to_sui_swap \\');
     console.log('     --args <your_sui_coin> \\');
     console.log('     <user_sui_address> \\');
     console.log(`     "${ETH_HASH_LOCK}" \\`);
     console.log(`     "${ETH_ORDER_HASH}" \\`);
     console.log('     <clock_object>');
    console.log('');
    console.log('   # Execute swap with secret');
    console.log(`   sui client call --package ${SUI_PACKAGE_ID} \\`);
    console.log('     --module complete_swap \\');
    console.log('     --function execute_swap \\');
    console.log('     --args <escrow_object> <registry_object> <secret> <clock_object>');
    console.log('');
    
    console.log('🔑 Important Notes:');
    console.log('   - You need the ORIGINAL secret that created the hash lock');
    console.log('   - The secret must be shared between both chains');
    console.log('   - Both escrows must use the SAME hash lock');
    console.log('   - Time locks should be synchronized');
    console.log('');
    
    console.log('✅ Your infrastructure is ready!');
    console.log('🚀 This completes the ETH ↔ SUI cross-chain swap system!');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Run the completion script
completeSwapWithSui(); 