import dotenv from 'dotenv';
import { RelayerConfig } from './relayer';

dotenv.config();

export const config: RelayerConfig = {
  // Ethereum Configuration
  ethRpcUrl: process.env.ETH_RPC_URL || 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
  ethPrivateKey: process.env.ETH_PRIVATE_KEY || '',
  factoryAddress: process.env.ETH_FACTORY_ADDRESS || '',
  resolverAddress: process.env.ETH_RESOLVER_ADDRESS || '',
  
  // Sui Configuration
  suiRpcUrl: process.env.SUI_RPC_URL || 'https://fullnode.testnet.sui.io:443',
  suiPrivateKey: process.env.SUI_PRIVATE_KEY || '',
  suiFactoryAddress: process.env.SUI_FACTORY_ADDRESS || '',
  suiPackageId: process.env.SUI_PACKAGE_ID || '',
  
  // Relayer Configuration
  pollingInterval: parseInt(process.env.POLLING_INTERVAL || '10000')
};

// Validate required configuration
export function validateConfig(config: RelayerConfig): void {
  const requiredFields = [
    'ethRpcUrl',
    'ethPrivateKey', 
    'factoryAddress',
    'resolverAddress',
    'suiRpcUrl',
    'suiPrivateKey',
    'suiFactoryAddress',
    'suiPackageId'
  ];

  for (const field of requiredFields) {
    if (!config[field as keyof RelayerConfig]) {
      throw new Error(`Missing required configuration: ${field}`);
    }
  }
} 