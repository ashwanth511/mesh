declare module '@mysten/sui.js' {
  export class JsonRpcProvider {
    constructor(options: { url: string });
    queryEvents(params: any): Promise<any>;
  }
  
  export class Ed25519Keypair {
    static fromSecretKey(secretKey: Uint8Array): Ed25519Keypair;
  }
  
  export class RawSigner {
    constructor(keypair: Ed25519Keypair, provider: JsonRpcProvider);
    signAndExecuteTransactionBlock(params: any): Promise<any>;
  }
  
  export class TransactionBlock {
    constructor();
    moveCall(params: any): any;
    publish(params: any): any;
    pure(params: any): any;
    object(objectId: string): any;
  }
  
  export function fromB64(data: string): Uint8Array;
  export function toB64(data: Uint8Array): string;
}

declare module '@mysten/sui.js' {
  export * from '@mysten/sui.js';
} 