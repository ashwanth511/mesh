"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateConfig = exports.config = void 0;
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
exports.config = {
    // Ethereum Configuration
    ethRpcUrl: process.env.ETH_RPC_URL || 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
    ethPrivateKey: process.env.ETH_PRIVATE_KEY || '',
    meshEscrowAddress: process.env.MESH_ESCROW_ADDRESS || '',
    meshCrossChainOrderAddress: process.env.MESH_CROSS_CHAIN_ORDER_ADDRESS || '',
    meshResolverNetworkAddress: process.env.MESH_RESOLVER_NETWORK_ADDRESS || '',
    meshLimitOrderProtocolAddress: process.env.MESH_LIMIT_ORDER_PROTOCOL_ADDRESS || '',
    meshDutchAuctionAddress: process.env.MESH_DUTCH_AUCTION_ADDRESS || '',
    // Sui Configuration
    suiRpcUrl: process.env.SUI_RPC_URL || 'https://fullnode.testnet.sui.io:443',
    suiPrivateKey: process.env.SUI_PRIVATE_KEY || '',
    suiPackageId: process.env.SUI_PACKAGE_ID || '',
    // Relayer Configuration
    pollingInterval: parseInt(process.env.POLLING_INTERVAL || '10000')
};
// Validate required configuration
function validateConfig(config) {
    const requiredFields = [
        'ethRpcUrl',
        'ethPrivateKey',
        'meshEscrowAddress',
        'meshCrossChainOrderAddress',
        'meshResolverNetworkAddress',
        'meshLimitOrderProtocolAddress',
        'meshDutchAuctionAddress',
        'suiRpcUrl',
        'suiPrivateKey',
        'suiPackageId'
    ];
    for (const field of requiredFields) {
        if (!config[field]) {
            throw new Error(`Missing required configuration: ${field}`);
        }
    }
}
exports.validateConfig = validateConfig;
//# sourceMappingURL=config.js.map