'use client';

import React from 'react';
import { WalletProvider } from '@suiet/wallet-kit';
import { WagmiProvider } from 'wagmi';
import { RainbowKitProvider, getDefaultConfig } from '@rainbow-me/rainbowkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { mainnet, sepolia } from 'wagmi/chains';
import { ClientOnly } from '@/components/client-only';

// RainbowKit configuration
const config = getDefaultConfig({
  appName: 'ETH-SUI Swap',
  projectId: 'demo-project-id', // Replace with your WalletConnect project ID
  chains: [mainnet, sepolia],
  ssr: true,
});

const queryClient = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ClientOnly>
      <WagmiProvider config={config}>
        <QueryClientProvider client={queryClient}>
          <RainbowKitProvider>
            <WalletProvider>
              {children}
            </WalletProvider>
          </RainbowKitProvider>
        </QueryClientProvider>
      </WagmiProvider>
    </ClientOnly>
  );
}
