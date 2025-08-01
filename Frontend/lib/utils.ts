import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Price fetching utilities
export async function fetchCryptoPrice(symbol: string): Promise<number> {
  try {
    const response = await fetch(
      `https://api.coingecko.com/api/v3/simple/price?ids=${symbol}&vs_currencies=usd`
    );
    const data = await response.json();
    return data[symbol]?.usd || 0;
  } catch (error) {
    console.error(`Error fetching price for ${symbol}:`, error);
    return 0;
  }
}

export async function fetchETHPrice(): Promise<number> {
  return fetchCryptoPrice('ethereum');
}

export async function fetchSUIPrice(): Promise<number> {
  return fetchCryptoPrice('sui');
}
