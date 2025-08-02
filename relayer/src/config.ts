import dotenv from 'dotenv';
import { RelayerConfig } from './relayer';

dotenv.config();

export const config: RelayerConfig = {
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
export function validateConfig(config: RelayerConfig): void {
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
    if (!config[field as keyof RelayerConfig]) {
      throw new Error(`Missing required configuration: ${field}`);
    }
  }
} 