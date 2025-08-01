'use client';

import { useEffect, useState } from 'react';
import { fetchETHPrice, fetchSUIPrice } from '@/lib/utils';
import { TrendingUp } from 'lucide-react';

interface PriceData {
  eth: number;
  sui: number;
}

export function PriceDisplay() {
  const [prices, setPrices] = useState<PriceData>({ eth: 0, sui: 0 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchPrices = async () => {
      try {
        const [ethPrice, suiPrice] = await Promise.all([
          fetchETHPrice(),
          fetchSUIPrice()
        ]);
        setPrices({ eth: ethPrice, sui: suiPrice });
      } catch (error) {
        console.error('Error fetching prices:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchPrices();
    const interval = setInterval(fetchPrices, 60000); // Update every minute

    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="flex space-x-4">
        <div className="animate-pulse bg-muted rounded p-2 w-24 h-8"></div>
        <div className="animate-pulse bg-muted rounded p-2 w-24 h-8"></div>
      </div>
    );
  }

  return (
    <div className="flex space-x-4 text-sm">
      <div className="flex items-center space-x-1 bg-muted/50 rounded-md px-3 py-1">
        <span className="font-medium">ETH:</span>
        <span className="text-green-600">${prices.eth.toLocaleString()}</span>
        <TrendingUp className="h-3 w-3 text-green-600" />
      </div>
      <div className="flex items-center space-x-1 bg-muted/50 rounded-md px-3 py-1">
        <span className="font-medium">SUI:</span>
        <span className="text-blue-600">${prices.sui.toFixed(2)}</span>
        <TrendingUp className="h-3 w-3 text-blue-600" />
      </div>
    </div>
  );
}
