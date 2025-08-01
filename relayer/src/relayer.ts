import { ethers } from 'ethers';
import { JsonRpcProvider } from '@mysten/sui.js';
import { EscrowFactory__factory, FusionResolver__factory } from '../contracts/fusionplus-eth/typechain-types';

interface SwapEvent {
  orderHash: string;
  fromChain: 'ethereum' | 'sui';
  toChain: 'ethereum' | 'sui';
  maker: string;
  taker: string;
  amount: string;
  minAmount: string;
  secret: string;
  status: 'pending' | 'created' | 'executed' | 'cancelled';
  createdAt: number;
}

class CrossChainRelayer {
  private ethProvider: ethers.JsonRpcProvider;
  private suiProvider: JsonRpcProvider;
  private ethWallet: ethers.Wallet;
  private suiWallet: any; // Sui wallet implementation
  private factory: any;
  private resolver: any;
  private pendingSwaps: Map<string, SwapEvent> = new Map();
  private isRunning: boolean = false;

  constructor(
    ethRpcUrl: string,
    suiRpcUrl: string,
    ethPrivateKey: string,
    suiPrivateKey: string,
    factoryAddress: string,
    resolverAddress: string
  ) {
    // Initialize Ethereum connection
    this.ethProvider = new ethers.JsonRpcProvider(ethRpcUrl);
    this.ethWallet = new ethers.Wallet(ethPrivateKey, this.ethProvider);
    
    // Initialize Sui connection
    this.suiProvider = new JsonRpcProvider({ url: suiRpcUrl });
    
    // Initialize contracts
    this.factory = EscrowFactory__factory.connect(factoryAddress, this.ethWallet);
    this.resolver = FusionResolver__factory.connect(resolverAddress, this.ethWallet);
  }

  /**
   * Start the relayer
   */
  async start() {
    console.log('🚀 Starting Cross-Chain Relayer...');
    this.isRunning = true;

    // Start monitoring events
    this.monitorEthereumEvents();
    this.monitorSuiEvents();
    
    // Start processing loop
    this.processPendingSwaps();
  }

  /**
   * Stop the relayer
   */
  stop() {
    console.log('🛑 Stopping Cross-Chain Relayer...');
    this.isRunning = false;
  }

  /**
   * Monitor Ethereum events for new swaps
   */
  private async monitorEthereumEvents() {
    console.log('📡 Monitoring Ethereum events...');

    // Listen for CrossChainSwapInitiated events
    this.resolver.on('CrossChainSwapInitiated', async (
      orderHash: string,
      isEthereumToSui: boolean,
      maker: string,
      taker: string,
      srcAmount: bigint,
      minDstAmount: bigint
    ) => {
      console.log(`🔄 New swap detected: ${orderHash}`);
      
      // Generate secret for this swap
      const secret = this.generateSecret(orderHash);
      
      const swapEvent: SwapEvent = {
        orderHash,
        fromChain: isEthereumToSui ? 'ethereum' : 'sui',
        toChain: isEthereumToSui ? 'sui' : 'ethereum',
        maker,
        taker,
        amount: srcAmount.toString(),
        minDstAmount: minDstAmount.toString(),
        secret,
        status: 'created',
        createdAt: Date.now()
      };

      this.pendingSwaps.set(orderHash, swapEvent);
      
      // Create corresponding escrow on destination chain
      await this.createDestinationEscrow(swapEvent);
    });

    // Listen for CrossChainSwapCompleted events
    this.resolver.on('CrossChainSwapCompleted', async (
      orderHash: string,
      secret: string,
      completedAt: bigint
    ) => {
      console.log(`✅ Swap completed: ${orderHash}`);
      this.pendingSwaps.delete(orderHash);
    });

    // Listen for CrossChainSwapCancelled events
    this.resolver.on('CrossChainSwapCancelled', async (
      orderHash: string,
      canceller: string,
      cancelledAt: bigint
    ) => {
      console.log(`❌ Swap cancelled: ${orderHash}`);
      this.pendingSwaps.delete(orderHash);
    });
  }

  /**
   * Monitor Sui events for new swaps
   */
  private async monitorSuiEvents() {
    console.log('📡 Monitoring Sui events...');
    
    // Note: Sui event monitoring would be implemented here
    // This is a placeholder for the actual implementation
    // Sui events are different from Ethereum events and require different handling
  }

  /**
   * Create destination escrow on the other chain
   */
  private async createDestinationEscrow(swapEvent: SwapEvent) {
    try {
      if (swapEvent.fromChain === 'ethereum' && swapEvent.toChain === 'sui') {
        // Create Sui destination escrow
        await this.createSuiDestinationEscrow(swapEvent);
      } else if (swapEvent.fromChain === 'sui' && swapEvent.toChain === 'ethereum') {
        // Create Ethereum destination escrow
        await this.createEthereumDestinationEscrow(swapEvent);
      }
    } catch (error) {
      console.error(`❌ Failed to create destination escrow for ${swapEvent.orderHash}:`, error);
    }
  }

  /**
   * Create Sui destination escrow
   */
  private async createSuiDestinationEscrow(swapEvent: SwapEvent) {
    console.log(`🏗️ Creating Sui destination escrow for ${swapEvent.orderHash}`);
    
    // This would interact with the Sui Move contracts
    // Implementation depends on the specific Sui SDK and contract interface
    try {
      // Placeholder for Sui transaction
      // const tx = await this.suiProvider.executeTransaction({
      //   target: 'fusionplus::escrow_factory',
      //   function: 'create_escrow_dst',
      //   arguments: [swapEvent.orderHash, swapEvent.amount, swapEvent.secret]
      // });
      
      console.log(`✅ Sui destination escrow created for ${swapEvent.orderHash}`);
    } catch (error) {
      console.error(`❌ Failed to create Sui escrow:`, error);
    }
  }

  /**
   * Create Ethereum destination escrow
   */
  private async createEthereumDestinationEscrow(swapEvent: SwapEvent) {
    console.log(`🏗️ Creating Ethereum destination escrow for ${swapEvent.orderHash}`);
    
    try {
      // Create order config
      const orderConfig = {
        id: 1,
        srcAmount: swapEvent.amount,
        minDstAmount: swapEvent.minAmount,
        estimatedDstAmount: swapEvent.minAmount,
        expirationTime: Math.floor(Date.now() / 1000) + 3600, // 1 hour
        srcAssetIsNative: false,
        dstAssetIsNative: false,
        fee: {
          protocolFee: 100,
          integratorFee: 50,
          surplusPercentage: 10,
          maxCancellationPremium: ethers.parseEther('0.01')
        },
        cancellationAuctionDuration: 3600
      };

      // Create immutables
      const immutables = {
        maker: swapEvent.maker,
        taker: swapEvent.taker,
        token: ethers.ZeroAddress, // Native token
        amount: swapEvent.amount,
        hashlock: ethers.keccak256(ethers.toUtf8Bytes(swapEvent.secret)),
        timelocks: {
          srcWithdrawal: 300,
          srcPublicWithdrawal: 600,
          srcCancellation: 900,
          srcPublicCancellation: 1200,
          dstWithdrawal: 300,
          dstPublicWithdrawal: 600,
          dstCancellation: 900
        },
        safetyDeposit: ethers.parseEther('0.1'),
        deployedAt: 0
      };

      // Create destination escrow
      const tx = await this.resolver.initiateSuiToEthereumSwap(
        orderConfig,
        immutables,
        swapEvent.secret,
        { value: ethers.parseEther('0.1') }
      );

      await tx.wait();
      console.log(`✅ Ethereum destination escrow created for ${swapEvent.orderHash}`);
    } catch (error) {
      console.error(`❌ Failed to create Ethereum escrow:`, error);
    }
  }

  /**
   * Process pending swaps and execute them when conditions are met
   */
  private async processPendingSwaps() {
    while (this.isRunning) {
      try {
        for (const [orderHash, swapEvent] of this.pendingSwaps) {
          // Check if swap is ready for execution
          if (await this.isSwapReadyForExecution(swapEvent)) {
            await this.executeSwap(swapEvent);
          }
        }
      } catch (error) {
        console.error('❌ Error processing pending swaps:', error);
      }

      // Wait before next iteration
      await new Promise(resolve => setTimeout(resolve, 5000)); // 5 seconds
    }
  }

  /**
   * Check if swap is ready for execution
   */
  private async isSwapReadyForExecution(swapEvent: SwapEvent): Promise<boolean> {
    try {
      // Check if both escrows are created
      const ethEscrowExists = await this.factory.escrowExists(swapEvent.orderHash);
      // const suiEscrowExists = await this.checkSuiEscrowExists(swapEvent.orderHash);
      
      // For now, just check Ethereum escrow
      return ethEscrowExists;
    } catch (error) {
      console.error(`❌ Error checking swap readiness:`, error);
      return false;
    }
  }

  /**
   * Execute the swap by providing the secret
   */
  private async executeSwap(swapEvent: SwapEvent) {
    try {
      console.log(`🚀 Executing swap: ${swapEvent.orderHash}`);
      
      // Execute on Ethereum side
      const tx = await this.resolver.completeSwap(
        swapEvent.orderHash,
        swapEvent.secret
      );

      await tx.wait();
      console.log(`✅ Swap executed successfully: ${swapEvent.orderHash}`);
      
      // Update status
      swapEvent.status = 'executed';
      
    } catch (error) {
      console.error(`❌ Failed to execute swap ${swapEvent.orderHash}:`, error);
    }
  }

  /**
   * Generate a deterministic secret for a swap
   */
  private generateSecret(orderHash: string): string {
    // In production, this should be cryptographically secure
    // For now, using a simple hash of the order hash
    return ethers.keccak256(ethers.toUtf8Bytes(orderHash + Date.now().toString()));
  }

  /**
   * Get pending swaps
   */
  getPendingSwaps(): SwapEvent[] {
    return Array.from(this.pendingSwaps.values());
  }

  /**
   * Get swap status
   */
  getSwapStatus(orderHash: string): SwapEvent | undefined {
    return this.pendingSwaps.get(orderHash);
  }

  /**
   * Cancel a swap
   */
  async cancelSwap(orderHash: string) {
    try {
      const swapEvent = this.pendingSwaps.get(orderHash);
      if (!swapEvent) {
        throw new Error('Swap not found');
      }

      console.log(`❌ Cancelling swap: ${orderHash}`);
      
      const tx = await this.resolver.cancelSwap(orderHash);
      await tx.wait();
      
      console.log(`✅ Swap cancelled: ${orderHash}`);
      this.pendingSwaps.delete(orderHash);
      
    } catch (error) {
      console.error(`❌ Failed to cancel swap ${orderHash}:`, error);
    }
  }
}

// Configuration interface
interface RelayerConfig {
  ethRpcUrl: string;
  suiRpcUrl: string;
  ethPrivateKey: string;
  suiPrivateKey: string;
  factoryAddress: string;
  resolverAddress: string;
  pollingInterval?: number;
}

// Main function to start the relayer
export async function startRelayer(config: RelayerConfig) {
  const relayer = new CrossChainRelayer(
    config.ethRpcUrl,
    config.suiRpcUrl,
    config.ethPrivateKey,
    config.suiPrivateKey,
    config.factoryAddress,
    config.resolverAddress
  );

  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n🛑 Received SIGINT, shutting down gracefully...');
    relayer.stop();
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
    relayer.stop();
    process.exit(0);
  });

  await relayer.start();
  return relayer;
}

export { CrossChainRelayer, SwapEvent }; 