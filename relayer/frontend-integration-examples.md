# 🎯 Frontend Integration Examples

## **Unified Mesh Resolver Service**

Your frontend can now choose between **TWO DELIVERY MODES**:

1. **⚡ INSTANT DELIVERY** (like unite-sui) - 5 seconds
2. **🏁 DUTCH AUCTION** (competitive pricing) - Variable time

## **Frontend API Examples:**

### **1. Instant Delivery Mode (5 seconds)**

```typescript
// Frontend calls this for instant delivery
const swapEthToSuiInstant = async (ethAmount: bigint) => {
  // User creates direct escrow (triggers instant resolver)
  const tx = await meshEscrow.createEscrowWithEth(
    hashLock,
    timeLock,
    userSuiAddress,
    'instant-delivery',
    { value: ethAmount }
  );
  
  // Resolver automatically creates and fills Sui escrow in 5 seconds!
  return tx;
};
```

### **2. Dutch Auction Mode (competitive pricing)**

```typescript
// Frontend calls this for Dutch auction
const swapEthToSuiAuction = async (ethAmount: bigint, destinationAmount: bigint) => {
  // User creates cross-chain order (triggers Dutch auction)
  const auctionConfig = {
    auctionStartTime: Math.floor(Date.now() / 1000) + 300, // 5 min delay
    auctionEndTime: Math.floor(Date.now() / 1000) + 3600,  // 1 hour total
    startRate: parseEther('1.2'), // 120% of market rate
    endRate: parseEther('0.8')    // 80% of market rate
  };
  
  const crossChainConfig = {
    suiOrderHash: 'sui-order-123',
    timelockDuration: 3600,
    destinationAddress: userSuiAddress,
    secretHash: hashLock
  };
  
  const tx = await meshCrossChainOrder.createCrossChainOrder(
    ethAmount,
    destinationAmount,
    auctionConfig,
    crossChainConfig
  );
  
  // Resolver monitors auction and executes when profitable
  return tx;
};
```

## **Frontend Component Example:**

```tsx
import { useState } from 'react';

export function SwapInterface() {
  const [deliveryMode, setDeliveryMode] = useState<'instant' | 'auction'>('instant');
  const [ethAmount, setEthAmount] = useState('0.002');
  
  const handleSwap = async () => {
    const amount = parseEther(ethAmount);
    
    if (deliveryMode === 'instant') {
      // INSTANT DELIVERY - 5 seconds like unite-sui
      console.log('🚀 Starting instant swap...');
      await swapEthToSuiInstant(amount);
      console.log('⚡ SUI will arrive in 5 seconds!');
      
    } else {
      // DUTCH AUCTION - competitive pricing
      console.log('🏁 Starting Dutch auction...');
      const suiAmount = amount * BigInt(1000); // 1 ETH = 1000 SUI
      await swapEthToSuiAuction(amount, suiAmount);
      console.log('📊 Waiting for best price...');
    }
  };
  
  return (
    <div className="swap-interface">
      <h2>Mesh Cross-Chain Swap</h2>
      
      {/* Delivery Mode Selection */}
      <div className="delivery-mode">
        <label>
          <input 
            type="radio" 
            checked={deliveryMode === 'instant'}
            onChange={() => setDeliveryMode('instant')}
          />
          ⚡ Instant Delivery (5 seconds)
        </label>
        
        <label>
          <input 
            type="radio" 
            checked={deliveryMode === 'auction'}
            onChange={() => setDeliveryMode('auction')}
          />
          🏁 Dutch Auction (best price)
        </label>
      </div>
      
      {/* Amount Input */}
      <input 
        type="number" 
        value={ethAmount}
        onChange={(e) => setEthAmount(e.target.value)}
        placeholder="ETH Amount"
      />
      
      {/* Swap Button */}
      <button onClick={handleSwap}>
        {deliveryMode === 'instant' 
          ? '⚡ Swap Instantly' 
          : '🏁 Start Auction'
        }
      </button>
      
      {/* Mode Description */}
      <div className="mode-info">
        {deliveryMode === 'instant' ? (
          <p>✅ Get SUI in 5 seconds (like unite-sui)</p>
        ) : (
          <p>📊 Get best price through competitive auction</p>
        )}
      </div>
    </div>
  );
}
```

## **Environment Configuration:**

```bash
# Enable/disable delivery modes
INSTANT_DELIVERY_ENABLED=true
DUTCH_AUCTION_ENABLED=true
INSTANT_DELIVERY_DELAY=5000  # 5 seconds

# Resolver configuration
RESOLVER_PRIVATE_KEY=your_resolver_private_key
SUI_RESOLVER_PRIVATE_KEY=your_sui_resolver_private_key
```

## **Benefits for Users:**

### **⚡ Instant Mode:**
- ✅ Predictable 5-second delivery
- ✅ No price uncertainty
- ✅ Great for small amounts
- ✅ Same UX as unite-sui

### **🏁 Auction Mode:**
- ✅ Best possible price
- ✅ Competitive resolver bidding
- ✅ Great for large amounts
- ✅ Transparent price discovery

## **Usage:**

```bash
# Start the unified resolver service
cd relayer
npm start

# Test instant delivery
npm run test-instant
```

**Now your frontend can offer BOTH instant delivery AND Dutch auction! 🎉**