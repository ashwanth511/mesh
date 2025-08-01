import { ethers } from 'ethers';
import { 
  JsonRpcProvider, 
  Ed25519Keypair, 
  RawSigner,
  TransactionBlock,
  fromB64,
  toB64
} from '@mysten/sui.js';
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

interface SuiEscrowEvent {
  orderHash: string;
  escrowAddress: string;
  isSource: boolean;
  amount: string;
  maker: string;
  taker: string;
}

class CrossChainRelayer {
  private ethProvider: ethers.JsonRpcProvider;
  private suiProvider: JsonRpcProvider;
  private ethWallet: ethers.Wallet;
  private suiWallet: Ed25519Keypair;
  private suiSigner: RawSigner;
  private factory: any;
  private resolver: any;
  private pendingSwaps: Map<string, SwapEvent> = new Map();
  private isRunning: boolean = false;
  private suiFactoryAddress: string;
  private suiPackageId: string;

  constructor(
    ethRpcUrl: string,
    suiRpcUrl: string,
    ethPrivateKey: string,
    suiPrivateKey: string,
    factoryAddress: string,
    resolverAddress: string,
    suiFactoryAddress: string,
    suiPackageId: string
  ) {
    // Initialize Ethereum connection
    this.ethProvider = new ethers.JsonRpcProvider(ethRpcUrl);
    this.ethWallet = new ethers.Wallet(ethPrivateKey, this.ethProvider);
    
    // Initialize Sui connection
    this.suiProvider = new JsonRpcProvider({ url: suiRpcUrl });
    this.suiWallet = Ed25519Keypair.fromSecretKey(fromB64(suiPrivateKey));
    this.suiSigner = new RawSigner(this.suiWallet, this.suiProvider);
    
    // Initialize contracts
    this.factory = EscrowFactory__factory.connect(factoryAddress, this.ethWallet);
    this.resolver = FusionResolver__factory.connect(resolverAddress, this.ethWallet);
    
    // Sui contract addresses
    this.suiFactoryAddress = suiFactoryAddress;
    this.suiPackageId = suiPackageId;
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
      console.log(`🔄 New Ethereum swap detected: ${orderHash}`);
      
      // Generate secret for this swap
      const secret = this.generateSecret(orderHash);
      
      const swapEvent: SwapEvent = {
        orderHash,
        fromChain: isEthereumToSui ? 'ethereum' : 'sui',
        toChain: isEthereumToSui ? 'sui' : 'ethereum',
        maker,
        taker,
        amount: srcAmount.toString(),
        minAmount: minDstAmount.toString(),
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
      console.log(`✅ Ethereum swap completed: ${orderHash}`);
      this.pendingSwaps.delete(orderHash);
    });

    // Listen for CrossChainSwapCancelled events
    this.resolver.on('CrossChainSwapCancelled', async (
      orderHash: string,
      canceller: string,
      cancelledAt: bigint
    ) => {
      console.log(`❌ Ethereum swap cancelled: ${orderHash}`);
      this.pendingSwaps.delete(orderHash);
    });
  }

  /**
   * Monitor Sui events for new swaps
   */
  private async monitorSuiEvents() {
    console.log('📡 Monitoring Sui events...');
    
    // Poll for Sui events since Sui doesn't have persistent event subscriptions like Ethereum
    setInterval(async () => {
      if (!this.isRunning) return;
      
      try {
        // Get recent events from Sui
        const events = await this.getSuiEvents();
        
        for (const event of events) {
          await this.handleSuiEvent(event);
        }
      } catch (error) {
        console.error('❌ Error monitoring Sui events:', error);
      }
    }, 5000); // Poll every 5 seconds
  }

  /**
   * Get Sui events from the blockchain
   */
  private async getSuiEvents(): Promise<SuiEscrowEvent[]> {
    try {
      // Query for EscrowCreated events
      const events = await this.suiProvider.queryEvents({
        query: {
          MoveModule: {
            package: this.suiPackageId,
            module: 'fusionplus'
          },
          MoveEventType: `${this.suiPackageId}::fusionplus::EscrowCreated`
        },
        limit: 10
      });

      return events.data.map(event => ({
        orderHash: event.parsedJson?.order_hash || '',
        escrowAddress: event.parsedJson?.escrow_address || '',
        isSource: event.parsedJson?.is_source || false,
        amount: event.parsedJson?.amount || '0',
        maker: event.parsedJson?.maker || '',
        taker: event.parsedJson?.taker || ''
      }));
    } catch (error) {
      console.error('❌ Error getting Sui events:', error);
      return [];
    }
  }

  /**
   * Handle Sui escrow events
   */
  private async handleSuiEvent(event: SuiEscrowEvent) {
    console.log(`🔄 New Sui escrow detected: ${event.orderHash}`);
    
    // Check if this is a new event we haven't processed
    if (this.pendingSwaps.has(event.orderHash)) {
      return; // Already processed
    }
    
    // Generate secret for this swap
    const secret = this.generateSecret(event.orderHash);
    
    const swapEvent: SwapEvent = {
      orderHash: event.orderHash,
      fromChain: event.isSource ? 'sui' : 'ethereum',
      toChain: event.isSource ? 'ethereum' : 'sui',
      maker: event.maker,
      taker: event.taker,
      amount: event.amount,
      minAmount: event.amount, // For simplicity, using same amount
      secret,
      status: 'created',
      createdAt: Date.now()
    };

    this.pendingSwaps.set(event.orderHash, swapEvent);
    
    // Create corresponding escrow on destination chain
    await this.createDestinationEscrow(swapEvent);
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
    
    try {
      const tx = new TransactionBlock();
      
      // Create timelocks for Sui
      const timelocks = tx.moveCall({
        target: `${this.suiPackageId}::fusionplus::create_timelocks_for_test`,
        arguments: [
          tx.pure(300),  // src_withdrawal
          tx.pure(600),  // src_public_withdrawal
          tx.pure(900),  // src_cancellation
          tx.pure(1200), // src_public_cancellation
          tx.pure(300),  // dst_withdrawal
          tx.pure(600),  // dst_public_withdrawal
          tx.pure(900)   // dst_cancellation
        ]
      });

      // Create immutables for Sui
      const immutables = tx.moveCall({
        target: `${this.suiPackageId}::fusionplus::create_immutables_for_test`,
        arguments: [
          tx.pure(swapEvent.maker),
          tx.pure(swapEvent.taker),
          tx.pure('0x2::sui::SUI'), // Native SUI token
          tx.pure(swapEvent.amount),
          tx.pure(this.hashSecret(swapEvent.secret)), // SHA3-256 hash
          timelocks,
          tx.pure(1000000), // safety_deposit (1 SUI)
          tx.pure(0) // deployed_at
        ]
      });

      // Create destination escrow
      tx.moveCall({
        target: `${this.suiPackageId}::fusionplus::create_escrow_dst`,
        arguments: [
          tx.object(this.suiFactoryAddress),
          immutables,
          tx.pure(swapEvent.amount), // amount to lock
          tx.pure(swapEvent.secret)  // secret
        ]
      });

      // Execute transaction
      const result = await this.suiSigner.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
          showEffects: true,
          showEvents: true
        }
      });

      console.log(`✅ Sui destination escrow created for ${swapEvent.orderHash} in tx: ${result.digest}`);
      
      // Update swap status
      swapEvent.status = 'created';
      
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
      
      // Update swap status
      swapEvent.status = 'created';
      
    } catch (error) {
      console.error(`❌ Failed to create Ethereum escrow:`, error);
    }
  }

  /**
   * Process pending swaps
   */
  private async processPendingSwaps() {
    while (this.isRunning) {
      try {
        for (const [orderHash, swapEvent] of this.pendingSwaps) {
          if (swapEvent.status === 'created' && await this.isSwapReadyForExecution(swapEvent)) {
            await this.executeSwap(swapEvent);
          }
        }
      } catch (error) {
        console.error('❌ Error processing pending swaps:', error);
      }
      
      // Wait before next iteration
      await new Promise(resolve => setTimeout(resolve, 10000)); // 10 seconds
    }
  }

  /**
   * Check if swap is ready for execution
   */
  private async isSwapReadyForExecution(swapEvent: SwapEvent): Promise<boolean> {
    try {
      // Check if both escrows exist
      if (swapEvent.fromChain === 'ethereum') {
        // Check if Ethereum escrow exists
        const escrowExists = await this.resolver.swaps(swapEvent.orderHash);
        return escrowExists.createdAt > 0;
      } else {
        // Check if Sui escrow exists (simplified check)
        return true; // For demo purposes
      }
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
      
      if (swapEvent.fromChain === 'ethereum') {
        // Execute on Ethereum side
        const tx = await this.resolver.completeSwap(
          swapEvent.orderHash,
          swapEvent.secret
        );

        await tx.wait();
        console.log(`✅ Ethereum swap executed successfully: ${swapEvent.orderHash}`);
        
        // Execute on Sui side
        await this.executeSuiWithdrawal(swapEvent);
        
      } else {
        // Execute on Sui side first
        await this.executeSuiWithdrawal(swapEvent);
        
        // Execute on Ethereum side
        const tx = await this.resolver.completeSwap(
          swapEvent.orderHash,
          swapEvent.secret
        );

        await tx.wait();
        console.log(`✅ Ethereum swap executed successfully: ${swapEvent.orderHash}`);
      }
      
      // Update status
      swapEvent.status = 'executed';
      
    } catch (error) {
      console.error(`❌ Failed to execute swap ${swapEvent.orderHash}:`, error);
    }
  }

  /**
   * Execute withdrawal on Sui
   */
  private async executeSuiWithdrawal(swapEvent: SwapEvent) {
    try {
      console.log(`🚀 Executing Sui withdrawal for: ${swapEvent.orderHash}`);
      
      const tx = new TransactionBlock();
      
      // Call withdraw function on Sui escrow
      tx.moveCall({
        target: `${this.suiPackageId}::fusionplus::withdraw_src`,
        arguments: [
          tx.pure(swapEvent.orderHash), // order_hash
          tx.pure(swapEvent.secret),    // secret
          tx.pure(swapEvent.amount)     // amount
        ]
      });

      const result = await this.suiSigner.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
          showEffects: true,
          showEvents: true
        }
      });

      console.log(`✅ Sui withdrawal executed successfully: ${swapEvent.orderHash} in tx: ${result.digest}`);
      
    } catch (error) {
      console.error(`❌ Failed to execute Sui withdrawal:`, error);
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
   * Hash secret using SHA3-256 for Sui
   */
  private hashSecret(secret: string): string {
    // Convert to bytes and hash using SHA3-256
    const encoder = new TextEncoder();
    const data = encoder.encode(secret);
    // This is a simplified hash - in production use proper SHA3-256
    return ethers.keccak256(data);
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
      
      if (swapEvent.fromChain === 'ethereum') {
        const tx = await this.resolver.cancelSwap(orderHash);
        await tx.wait();
      } else {
        // Cancel on Sui
        await this.cancelSuiSwap(swapEvent);
      }
      
      console.log(`✅ Swap cancelled: ${orderHash}`);
      this.pendingSwaps.delete(orderHash);
      
    } catch (error) {
      console.error(`❌ Failed to cancel swap ${orderHash}:`, error);
    }
  }

  /**
   * Cancel swap on Sui
   */
  private async cancelSuiSwap(swapEvent: SwapEvent) {
    try {
      console.log(`❌ Cancelling Sui swap: ${swapEvent.orderHash}`);
      
      const tx = new TransactionBlock();
      
      // Call cancel function on Sui escrow
      tx.moveCall({
        target: `${this.suiPackageId}::fusionplus::cancel_src`,
        arguments: [
          tx.pure(swapEvent.orderHash), // order_hash
          tx.pure(swapEvent.amount)     // amount
        ]
      });

      const result = await this.suiSigner.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
          showEffects: true,
          showEvents: true
        }
      });

      console.log(`✅ Sui swap cancelled successfully: ${swapEvent.orderHash} in tx: ${result.digest}`);
      
    } catch (error) {
      console.error(`❌ Failed to cancel Sui swap:`, error);
    }
  }
}

// Configuration interface
export interface RelayerConfig {
  ethRpcUrl: string;
  suiRpcUrl: string;
  ethPrivateKey: string;
  suiPrivateKey: string;
  factoryAddress: string;
  resolverAddress: string;
  suiFactoryAddress: string;
  suiPackageId: string;
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
    config.resolverAddress,
    config.suiFactoryAddress,
    config.suiPackageId
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