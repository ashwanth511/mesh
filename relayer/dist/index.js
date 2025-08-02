#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const relayer_1 = require("./relayer");
const config_1 = require("./config");
async function main() {
    try {
        console.log('🚀 Starting Fusion+ Cross-Chain Relayer...');
        // Validate configuration
        (0, config_1.validateConfig)(config_1.config);
        console.log('✅ Configuration validated');
        console.log('📡 Connecting to networks...');
        console.log(`   Ethereum: ${config_1.config.ethRpcUrl}`);
        console.log(`   Sui: ${config_1.config.suiRpcUrl}`);
        // Start the relayer
        const relayer = await (0, relayer_1.startRelayer)(config_1.config);
        console.log('✅ Relayer started successfully!');
        console.log('📊 Monitoring for cross-chain swaps...');
        console.log('🛑 Press Ctrl+C to stop');
    }
    catch (error) {
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
//# sourceMappingURL=index.js.map