#!/usr/bin/env node

import { startRelayer } from './relayer';
import { config, validateConfig } from './config';

async function main() {
  try {
    console.log('🚀 Starting Fusion+ Cross-Chain Relayer...');
    
    // Validate configuration
    validateConfig(config);
    
    console.log('✅ Configuration validated');
    console.log('📡 Connecting to networks...');
    console.log(`   Ethereum: ${config.ethRpcUrl}`);
    console.log(`   Sui: ${config.suiRpcUrl}`);
    
    // Start the relayer
    const relayer = await startRelayer(config);
    
    console.log('✅ Relayer started successfully!');
    console.log('📊 Monitoring for cross-chain swaps...');
    console.log('🛑 Press Ctrl+C to stop');
    
  } catch (error) {
    console.error('❌ Failed to start relayer:', error);
    process.exit(1);
  }
}

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Start the application
main(); 