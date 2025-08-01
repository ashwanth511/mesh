'use client';

import { useState, useEffect } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { ConnectButton as SuietConnectButton } from '@suiet/wallet-kit';
import { useAccount } from 'wagmi';
import { useWallet } from '@suiet/wallet-kit';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { SwapPriceDisplay } from '@/components/swap-price-display';
import { ClientOnly } from '@/components/client-only';
import { fetchETHPrice, fetchSUIPrice } from '@/lib/utils';
import LightRays from '@/components/ui/LightRays';
import { 
  ArrowRightLeft, 
  ArrowDownUp, 
  Info, 
  Clock, 
  Shield,
  Loader2,
  Copy,
  CheckCircle
} from 'lucide-react';
import Image from 'next/image';

interface SwapData {
  fromAmount: string;
  toAmount: string;
  fromNetwork: 'ethereum' | 'sui';
  toNetwork: 'ethereum' | 'sui';
  ethPrice: number;
  suiPrice: number;
  destinationAddress: string;
}

function SwapInterface() {
  const { address: ethAddress, isConnected: isEthConnected } = useAccount();
  const { connected: isSuiConnected, address: suiAddress } = useWallet();
  
  const [swapData, setSwapData] = useState<SwapData>({
    fromAmount: '',
    toAmount: '',
    fromNetwork: 'ethereum',
    toNetwork: 'sui',
    ethPrice: 0,
    suiPrice: 0,
    destinationAddress: ''
  });
  
  const [isLoading, setIsLoading] = useState(false);
  const [txStatus, setTxStatus] = useState<'idle' | 'pending' | 'success' | 'error'>('idle');
  const [addressCopied, setAddressCopied] = useState(false);

  // Fetch prices on component mount
  useEffect(() => {
    const fetchPrices = async () => {
      const [ethPrice, suiPrice] = await Promise.all([
        fetchETHPrice(),
        fetchSUIPrice()
      ]);
      setSwapData(prev => ({ ...prev, ethPrice, suiPrice }));
    };
    fetchPrices();
  }, []);

  // Calculate conversion when amount changes
  useEffect(() => {
    if (swapData.fromAmount && swapData.ethPrice && swapData.suiPrice) {
      const fromAmount = parseFloat(swapData.fromAmount);
      if (!isNaN(fromAmount)) {
        let toAmount: number;
        if (swapData.fromNetwork === 'ethereum') {
          // ETH to SUI conversion
          toAmount = (fromAmount * swapData.ethPrice) / swapData.suiPrice;
        } else {
          // SUI to ETH conversion
          toAmount = (fromAmount * swapData.suiPrice) / swapData.ethPrice;
        }
        setSwapData(prev => ({ ...prev, toAmount: toAmount.toFixed(6) }));
      }
    }
  }, [swapData.fromAmount, swapData.ethPrice, swapData.suiPrice, swapData.fromNetwork]);

  const handleFlipNetworks = () => {
    setSwapData(prev => ({
      ...prev,
      fromNetwork: prev.toNetwork,
      toNetwork: prev.fromNetwork,
      fromAmount: prev.toAmount,
      toAmount: prev.fromAmount,
      destinationAddress: ''
    }));
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setAddressCopied(true);
      setTimeout(() => setAddressCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy: ', err);
    }
  };

  const handleSwap = async () => {
    const requiredWallet = swapData.fromNetwork === 'ethereum' ? isEthConnected : isSuiConnected;
    if (!requiredWallet || !swapData.destinationAddress) {
      alert(`Please connect your ${swapData.fromNetwork === 'ethereum' ? 'Ethereum' : 'Sui'} wallet and enter destination address`);
      return;
    }

    setIsLoading(true);
    setTxStatus('pending');

    try {
      // Simulate Swap transaction
      await new Promise(resolve => setTimeout(resolve, 3000));
      setTxStatus('success');
    } catch (error) {
      console.error('Swap error:', error);
      setTxStatus('error');
    } finally {
      setIsLoading(false);
    }
  };

  const isValidSwap = swapData.fromAmount && 
                     parseFloat(swapData.fromAmount) > 0 && 
                     swapData.destinationAddress &&
                     (swapData.fromNetwork === 'ethereum' ? isEthConnected : isSuiConnected);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="text-center">
        <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold mb-4">
          Cross-Chain Swap
        </h1>
        <p className="text-muted-foreground mb-6 text-sm sm:text-base">
          Seamlessly transfer assets between Ethereum and Sui networks
        </p>
      </div>

      {/* Price Display */}
      <SwapPriceDisplay fromNetwork={swapData.fromNetwork} toNetwork={swapData.toNetwork} />

      {/* Swap Interface */}
      <Card>
        <CardHeader className="pb-4">
          <CardTitle className="flex items-center gap-2 text-lg sm:text-xl">
            <ArrowRightLeft className="h-5 w-5" />
            Swap Assets
          </CardTitle>
          <CardDescription className="text-sm">
            Transfer your tokens between Ethereum and Sui networks
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* From Section */}
          <div className="space-y-3">
            <label className="text-sm font-medium">From</label>
            <div className="p-4 border rounded-lg space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Network</span>
                <div className="flex items-center gap-2">
                  <div className="relative w-5 h-5">
                    <Image 
                      src={swapData.fromNetwork === 'ethereum' ? '/eth.svg' : '/sui.svg'} 
                      alt={swapData.fromNetwork === 'ethereum' ? 'Ethereum' : 'Sui'} 
                      width={20} 
                      height={20}
                      className="rounded-full"
                    />
                  </div>
                  <span className="font-medium">
                    {swapData.fromNetwork === 'ethereum' ? 'Ethereum' : 'Sui'}
                  </span>
                </div>
              </div>
              
              {/* Wallet Connection */}
              <div className="space-y-2">
                <div className="text-sm text-muted-foreground">
                  {swapData.fromNetwork === 'ethereum' ? 'Ethereum Wallet' : 'Sui Wallet'}
                </div>
                {swapData.fromNetwork === 'ethereum' ? (
                  <ConnectButton />
                ) : (
                  <SuietConnectButton />
                )}
                {((swapData.fromNetwork === 'ethereum' && isEthConnected && ethAddress) || 
                  (swapData.fromNetwork === 'sui' && isSuiConnected && suiAddress)) && (
                  <div className="flex items-center gap-2 text-xs text-muted-foreground">
                    <span>Connected:</span>
                    <span className="font-mono">
                      {swapData.fromNetwork === 'ethereum' 
                        ? `${ethAddress?.slice(0, 6)}...${ethAddress?.slice(-4)}`
                        : `${suiAddress?.slice(0, 6)}...${suiAddress?.slice(-4)}`
                      }
                    </span>
                  </div>
                )}
              </div>

              <Input
                type="number"
                placeholder="0.0"
                value={swapData.fromAmount}
                onChange={(e) => setSwapData(prev => ({ ...prev, fromAmount: e.target.value }))}
                className="text-base sm:text-lg"
              />
              <div className="flex justify-between text-sm text-muted-foreground">
                <span>Token: {swapData.fromNetwork === 'ethereum' ? 'ETH' : 'SUI'}</span>
                <span>
                  ~${swapData.fromAmount && !isNaN(parseFloat(swapData.fromAmount)) 
                    ? (parseFloat(swapData.fromAmount) * (swapData.fromNetwork === 'ethereum' ? swapData.ethPrice : swapData.suiPrice)).toLocaleString()
                    : '0'}
                </span>
              </div>
            </div>
          </div>

          {/* Flip Button */}
          <div className="flex justify-center">
            <Button
              variant="outline"
              size="icon"
              onClick={handleFlipNetworks}
              className="rounded-full"
            >
              <ArrowDownUp className="h-4 w-4" />
            </Button>
          </div>

          {/* To Section */}
          <div className="space-y-3">
            <label className="text-sm font-medium">To</label>
            <div className="p-4 border rounded-lg space-y-4 bg-muted/20">
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Network</span>
                <div className="flex items-center gap-2">
                  <div className="relative w-5 h-5">
                    <Image 
                      src={swapData.toNetwork === 'ethereum' ? '/eth.svg' : '/sui.svg'} 
                      alt={swapData.toNetwork === 'ethereum' ? 'Ethereum' : 'Sui'} 
                      width={20} 
                      height={20}
                      className="rounded-full"
                    />
                  </div>
                  <span className="font-medium">
                    {swapData.toNetwork === 'ethereum' ? 'Ethereum' : 'Sui'}
                  </span>
                </div>
              </div>

              {/* Destination Address Input */}
              <div className="space-y-2">
                <div className="text-sm text-muted-foreground">
                  {swapData.toNetwork === 'ethereum' ? 'Ethereum Address' : 'Sui Address'}
                </div>
                <div className="flex gap-2">
                  <Input
                    type="text"
                    placeholder={`Enter ${swapData.toNetwork === 'ethereum' ? 'Ethereum' : 'Sui'} address`}
                    value={swapData.destinationAddress}
                    onChange={(e) => setSwapData(prev => ({ ...prev, destinationAddress: e.target.value }))}
                    className="font-mono text-sm"
                  />
                  {((swapData.toNetwork === 'ethereum' && isEthConnected && ethAddress) || 
                    (swapData.toNetwork === 'sui' && isSuiConnected && suiAddress)) && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        const address = swapData.toNetwork === 'ethereum' ? ethAddress : suiAddress;
                        if (address) {
                          setSwapData(prev => ({ ...prev, destinationAddress: address }));
                          copyToClipboard(address);
                        }
                      }}
                      className="px-3"
                    >
                      {addressCopied ? <CheckCircle className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                    </Button>
                  )}
                </div>
              </div>

              <div className="text-base sm:text-lg font-medium py-3 px-3 bg-background rounded border min-h-[48px] flex items-center">
                {swapData.toAmount || '0.0'}
              </div>
              <div className="flex justify-between text-sm text-muted-foreground">
                <span>Token: {swapData.toNetwork === 'ethereum' ? 'ETH' : 'SUI'}</span>
                <span>
                  ~${swapData.toAmount && !isNaN(parseFloat(swapData.toAmount))
                    ? (parseFloat(swapData.toAmount) * (swapData.toNetwork === 'ethereum' ? swapData.ethPrice : swapData.suiPrice)).toLocaleString()
                    : '0'}
                </span>
              </div>
            </div>
          </div>

          {/* Swap Details */}
          <div className="space-y-3 p-4 bg-muted/20 rounded-lg">
            <h4 className="font-medium flex items-center gap-2 text-sm sm:text-base">
              <Info className="h-4 w-4" />
              Swap Details
            </h4>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Exchange Rate</span>
                <span className="text-xs sm:text-sm">
                  1 {swapData.fromNetwork === 'ethereum' ? 'ETH' : 'SUI'} = {
                    swapData.fromNetwork === 'ethereum' 
                      ? (swapData.ethPrice / swapData.suiPrice).toFixed(2)
                      : (swapData.suiPrice / swapData.ethPrice).toFixed(6)
                  } {swapData.toNetwork === 'ethereum' ? 'ETH' : 'SUI'}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Estimated Time</span>
                <span className="flex items-center gap-1 text-xs sm:text-sm">
                  <Clock className="h-3 w-3" />
                  1-3 minutes
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-muted-foreground">Network Fee</span>
                <span className="text-xs sm:text-sm">~$5-15</span>
              </div>
            </div>
          </div>

          {/* Swap Button */}
          <Button 
            className="w-full h-12 text-sm sm:text-base"
            onClick={handleSwap}
            disabled={!isValidSwap || isLoading}
          >
            {isLoading ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Processing...
              </>
            ) : !(swapData.fromNetwork === 'ethereum' ? isEthConnected : isSuiConnected) ? (
              `Connect ${swapData.fromNetwork === 'ethereum' ? 'Ethereum' : 'Sui'} Wallet`
            ) : !swapData.destinationAddress ? (
              'Enter Destination Address'
            ) : !swapData.fromAmount || parseFloat(swapData.fromAmount) <= 0 ? (
              'Enter Amount'
            ) : (
              <>
                <ArrowRightLeft className="mr-2 h-4 w-4" />
                Swap Assets
              </>
            )}
          </Button>
        </CardContent>
      </Card>

      {/* Transaction Status */}
      {txStatus !== 'idle' && (
        <Card>
          <CardContent className="pt-6">
            <div className="text-center">
              {txStatus === 'pending' && (
                <div className="space-y-4">
                  <Loader2 className="h-8 w-8 animate-spin mx-auto text-blue-600" />
                  <div>
                    <h3 className="font-medium">Processing Transaction</h3>
                    <p className="text-sm text-muted-foreground">
                      Your Swap transaction is being processed...
                    </p>
                  </div>
                </div>
              )}
              
              {txStatus === 'success' && (
                <div className="space-y-4">
                  <div className="w-8 h-8 bg-green-100 dark:bg-green-900 rounded-full flex items-center justify-center mx-auto">
                    <ArrowRightLeft className="h-4 w-4 text-green-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-green-600">Swap Successful!</h3>
                    <p className="text-sm text-muted-foreground">
                      Your assets have been successfully Swapped to {swapData.toNetwork}
                    </p>
                  </div>
                  <Button 
                    variant="outline" 
                    onClick={() => setTxStatus('idle')}
                  >
                    Start New Swap
                  </Button>
                </div>
              )}
              
              {txStatus === 'error' && (
                <div className="space-y-4">
                  <div className="w-8 h-8 bg-red-100 dark:bg-red-900 rounded-full flex items-center justify-center mx-auto">
                    <Info className="h-4 w-4 text-red-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-red-600">Swap Failed</h3>
                    <p className="text-sm text-muted-foreground">
                      There was an error processing your Swap transaction
                    </p>
                  </div>
                  <Button 
                    variant="outline" 
                    onClick={() => setTxStatus('idle')}
                  >
                    Try Again
                  </Button>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Security Notice */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex items-start gap-3">
            <Shield className="h-5 w-5 text-blue-600 mt-0.5 flex-shrink-0" />
            <div>
              <h4 className="font-medium mb-2 text-sm sm:text-base">Security Notice</h4>
              <p className="text-xs sm:text-sm text-muted-foreground">
                This is a demo swap interface. In a production environment, ensure you&apos;re using 
                audited smart contracts and verify all transaction details before proceeding. 
                The actual swap logic would include proper validation, fee calculation, and 
                cross-chain communication protocols.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function SwapPage() {
  return (
    <>
     <div className="fixed m-20 inset-0 z-0 opacity-70">
       <LightRays
          raysOrigin="top-center"
          raysColor="#ffffff"
          raysSpeed={1.5}
          lightSpread={0.4}
          rayLength={1.5}
          followMouse={true}
          mouseInfluence={0.1}
          noiseAmount={0.1}
          distortion={0.05}
          className="w-full  h-full"
        />
        </div>
    <section className="min-h-screen bg-background py-16 md:py-32">
      <div className="mx-auto max-w-5xl px-6">
        <div className="mx-auto max-w-2xl">
          <div className="bg-white/90 dark:bg-zinc-900/80 rounded-2xl shadow-xl border border-zinc-200 dark:border-zinc-800 p-6 md:p-10 space-y-8">
            <ClientOnly>
              <SwapInterface />
            </ClientOnly>
          </div>
        </div>
      </div>
    </section>
    </>
  );
}
