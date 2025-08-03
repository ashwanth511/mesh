import dotenv from 'dotenv';
import { RelayerConfig } from './relayer';

dotenv.config();

export const config: RelayerConfig = {
  // Ethereum Configuration
  ethRpcUrl: process.env.ETH_RPC_URL || 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
  ethPrivateKey: process.env.ETH_PRIVATE_KEY || '',
  meshEscrowAddress: process.env.MESH_ESCROW_ADDRESS || '0x29128871b80081B7115E2636659A34f82ADB168e',
  meshCrossChainOrderAddress: process.env.MESH_CROSS_CHAIN_ORDER_ADDRESS || '0x4513EFD3CE9F41075cebcab4596D24cA123d4fcc',
  meshResolverNetworkAddress: process.env.MESH_RESOLVER_NETWORK_ADDRESS || '0xEF48c1eD49A7286dc3094b08911c0D8A75Fa394c',
  meshLimitOrderProtocolAddress: process.env.MESH_LIMIT_ORDER_PROTOCOL_ADDRESS || '0xE4d8fAeE93a594e5d758Db8b2A8c54855a98a23d',
  meshDutchAuctionAddress: process.env.MESH_DUTCH_AUCTION_ADDRESS || '0xDb0ab33fB5C42491C8E8A65d12329B9C0a1c6f37',
  
  // Sui Configuration
  suiRpcUrl: process.env.SUI_RPC_URL || 'https://fullnode.testnet.sui.io:443',
  suiPrivateKey: process.env.SUI_PRIVATE_KEY || '',
  suiPackageId: process.env.SUI_PACKAGE_ID || '0x19e8821daaf73d8499290975a828f6637bb46b3beade26ce430d060b3cf95908',
  
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