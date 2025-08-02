'use client';

import { useEffect, useState } from 'react';
import { fetchETHPrice, fetchSUIPrice } from '@/lib/utils';
import { TrendingUp } from 'lucide-react';
import Image from 'next/image';

interface PriceData {
  eth: number;
  sui: number;
}

interface SwapPriceDisplayProps {
  fromNetwork: 'ethereum' | 'sui';
  toNetwork: 'ethereum' | 'sui';
}

export function SwapPriceDisplay({ fromNetwork, toNetwork }: SwapPriceDisplayProps) {
  const [prices, setPrices] = useState<PriceData>({ eth: 0, sui: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;
    const fetchPrices = async () => {
      try {
        const [ethPrice, suiPrice] = await Promise.all([
          fetchETHPrice(),
          fetchSUIPrice()
        ]);
        if (isMounted) setPrices({ eth: ethPrice, sui: suiPrice });
      } catch (error) {
        console.error('Error fetching prices:', error);
      } finally {
        if (isMounted) setLoading(false);
      }
    };

    fetchPrices();
    const interval = setInterval(fetchPrices, 10000); // Update every 10 seconds

    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, []);

  if (loading) {
    return (
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="animate-pulse bg-muted rounded-lg p-4 h-20"></div>
        <div className="animate-pulse bg-muted rounded-lg p-4 h-20"></div>
      </div>
    );
  }

  const exchangeRate = fromNetwork === 'ethereum' 
    ? (prices.eth / prices.sui)
    : (prices.sui / prices.eth);

  return (
    <div className="space-y-4">
      {/* Live Prices */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="bg-blue-50 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
          <div className="flex items-center space-x-3">
            <div className="relative w-8 h-8">
              <Image 
                src="/eth.svg" 
                alt="Ethereum" 
                width={32} 
                height={32}
                className="rounded-full"
              />
            </div>
            <div>
              <div className="text-sm font-medium text-blue-700 dark:text-blue-300">Ethereum</div>
              <div className="text-lg font-bold text-blue-900 dark:text-blue-100">
                ${prices.eth.toLocaleString()}
              </div>
            </div>
            <TrendingUp className="h-4 w-4 text-green-600 ml-auto" />
          </div>
        </div>

        <div className="bg-cyan-50 dark:bg-cyan-950/30 border border-cyan-200 dark:border-cyan-800 rounded-lg p-4">
          <div className="flex items-center space-x-3">
            <div className="relative w-8 h-8">
              <Image 
                src="/sui.svg" 
                alt="Sui" 
                width={32} 
                height={32}
                className="rounded-full"
              />
            </div>
            <div>
              <div className="text-sm font-medium text-cyan-700 dark:text-cyan-300">Sui</div>
              <div className="text-lg font-bold text-cyan-900 dark:text-cyan-100">
                ${prices.sui.toFixed(2)}
              </div>
            </div>
            <TrendingUp className="h-4 w-4 text-green-600 ml-auto" />
          </div>
        </div>
      </div>

      {/* Exchange Rate */}
      <div className="bg-muted/50 rounded-lg p-4 text-center">
        <div className="text-sm text-muted-foreground mb-1">Current Exchange Rate</div>
        <div className="font-medium">
          1 {fromNetwork === 'ethereum' ? 'ETH' : 'SUI'} = {exchangeRate.toFixed(fromNetwork === 'ethereum' ? 2 : 6)} {toNetwork === 'ethereum' ? 'ETH' : 'SUI'}
        </div>
      </div>
    </div>
  );
}
