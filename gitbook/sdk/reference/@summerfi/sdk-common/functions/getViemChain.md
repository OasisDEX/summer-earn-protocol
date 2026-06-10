# Function: getViemChain()

```ts
function getViemChain(chainId): 
  | {
  blockExplorers: {
     default: {
        apiUrl: "https://api.basescan.org/api";
        name: "Basescan";
        url: "https://basescan.org";
     };
  };
  blockTime: 2000;
  contracts: {
     disputeGameFactory: {
        1: {
           address: "0x43edB88C4B80fDD2AdFF2412A7BebF9dF42cB40e";
        };
     };
     gasPriceOracle: {
        address: "0x420000000000000000000000000000000000000F";
     };
     l1Block: {
        address: "0x4200000000000000000000000000000000000015";
     };
     l1StandardBridge: {
        1: {
           address: "0x3154Cf16ccdb4C6d922629664174b904d80F2C35";
           blockCreated: 17482143;
        };
     };
     l2CrossDomainMessenger: {
        address: "0x4200000000000000000000000000000000000007";
     };
     l2Erc721Bridge: {
        address: "0x4200000000000000000000000000000000000014";
     };
     l2OutputOracle: {
        1: {
           address: "0x56315b90c40730925ec5485cf004d835058518A0";
        };
     };
     l2StandardBridge: {
        address: "0x4200000000000000000000000000000000000010";
     };
     l2ToL1MessagePasser: {
        address: "0x4200000000000000000000000000000000000016";
     };
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 5022;
     };
     portal: {
        1: {
           address: "0x49048044D57e1C92A77f79988d21Fa8fAF74E97e";
           blockCreated: 17482143;
        };
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters: {
     block: {
        exclude: [] | undefined;
        format: (args, action?) => object;
        type: "block";
     };
     transaction: {
        exclude: [] | undefined;
        format: (args, action?) => 
           | {
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: boolean;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: bigint;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash: `0x${string}`;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "deposit";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList?: undefined;
           authorizationList?: undefined;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId?: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice: bigint;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas?: undefined;
           maxPriorityFeePerGas?: undefined;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "legacy";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity?: undefined;
         }
           | {
           accessList: AccessList;
           authorizationList?: undefined;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice: bigint;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas?: undefined;
           maxPriorityFeePerGas?: undefined;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip2930";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList: AccessList;
           authorizationList?: undefined;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip1559";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList: AccessList;
           authorizationList?: undefined;
           blobVersionedHashes: readonly `0x${string}`[];
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas: bigint;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip4844";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList: AccessList;
           authorizationList: SignedAuthorizationList<number>;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip7702";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
        };
        type: "transaction";
     };
     transactionReceipt: {
        exclude: [] | undefined;
        format: (args, action?) => object;
        type: "transactionReceipt";
     };
  };
  id: 8453;
  name: "Base";
  nativeCurrency: {
     decimals: 18;
     name: "Ether";
     symbol: "ETH";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://mainnet.base.org"];
     };
  };
  serializers: {
     transaction: (transaction, signature?) => 
        | `0x02${string}`
        | `0x01${string}`
        | `0x03${string}`
        | `0x04${string}`
        | TransactionSerializedLegacy
       | `0x7e${string}`;
  };
  sourceId: 1;
  testnet?: boolean;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
  | {
  blockExplorers: {
     default: {
        apiUrl: "https://api.etherscan.io/api";
        name: "Etherscan";
        url: "https://etherscan.io";
     };
  };
  blockTime: 12000;
  contracts: {
     ensUniversalResolver: {
        address: "0xeeeeeeee14d718c2b47d9923deab1335e144eeee";
        blockCreated: 23085558;
     };
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 14353601;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 1;
  name: "Ethereum";
  nativeCurrency: {
     decimals: 18;
     name: "Ether";
     symbol: "ETH";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://eth.merkle.io"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
  sourceId?: number;
  testnet?: boolean;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
  | {
  blockExplorers: {
     default: {
        apiUrl: "https://api.arbiscan.io/api";
        name: "Arbiscan";
        url: "https://arbiscan.io";
     };
  };
  blockTime: 250;
  contracts: {
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 7654707;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 42161;
  name: "Arbitrum One";
  nativeCurrency: {
     decimals: 18;
     name: "Ether";
     symbol: "ETH";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://arb1.arbitrum.io/rpc"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
  sourceId?: number;
  testnet?: boolean;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
  | {
  blockExplorers: {
     default: {
        name: "Sonic Explorer";
        url: "https://sonicscan.org";
     };
  };
  blockTime: 630;
  contracts: {
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 60;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 146;
  name: "Sonic";
  nativeCurrency: {
     decimals: 18;
     name: "Sonic";
     symbol: "S";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://rpc.soniclabs.com"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
  sourceId?: number;
  testnet: false;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
  | {
  blockExplorers: {
     default: {
        apiUrl: "https://api.hyperevmscan.io/api";
        name: "HyperEVMScan";
        url: "https://hyperevmscan.io";
     };
  };
  blockTime?: number;
  contracts: {
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 13051;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 999;
  name: "HyperEVM";
  nativeCurrency: {
     decimals: 18;
     name: "HYPE";
     symbol: "HYPE";
  };
  prepareTransactionRequest?:   | PrepareTransactionRequestFn
     | [PrepareTransactionRequestFn, object];
  rpcUrls: {
     default: {
        http: readonly ["https://rpc.hyperliquid.xyz/evm"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable>;
  sourceId?: number;
  testnet?: boolean;
  verifyHash?: ChainVerifyHashFn;
};
```

Defined in: [sdk/sdk-common/src/common/utils/getViemChain.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/utils/getViemChain.ts#L29)

## Parameters

### chainId

[`ChainId`](../type-aliases/ChainId.md)

## Returns

```ts
{
  blockExplorers: {
     default: {
        apiUrl: "https://api.basescan.org/api";
        name: "Basescan";
        url: "https://basescan.org";
     };
  };
  blockTime: 2000;
  contracts: {
     disputeGameFactory: {
        1: {
           address: "0x43edB88C4B80fDD2AdFF2412A7BebF9dF42cB40e";
        };
     };
     gasPriceOracle: {
        address: "0x420000000000000000000000000000000000000F";
     };
     l1Block: {
        address: "0x4200000000000000000000000000000000000015";
     };
     l1StandardBridge: {
        1: {
           address: "0x3154Cf16ccdb4C6d922629664174b904d80F2C35";
           blockCreated: 17482143;
        };
     };
     l2CrossDomainMessenger: {
        address: "0x4200000000000000000000000000000000000007";
     };
     l2Erc721Bridge: {
        address: "0x4200000000000000000000000000000000000014";
     };
     l2OutputOracle: {
        1: {
           address: "0x56315b90c40730925ec5485cf004d835058518A0";
        };
     };
     l2StandardBridge: {
        address: "0x4200000000000000000000000000000000000010";
     };
     l2ToL1MessagePasser: {
        address: "0x4200000000000000000000000000000000000016";
     };
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 5022;
     };
     portal: {
        1: {
           address: "0x49048044D57e1C92A77f79988d21Fa8fAF74E97e";
           blockCreated: 17482143;
        };
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters: {
     block: {
        exclude: [] | undefined;
        format: (args, action?) => object;
        type: "block";
     };
     transaction: {
        exclude: [] | undefined;
        format: (args, action?) => 
           | {
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: boolean;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: bigint;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash: `0x${string}`;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "deposit";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList?: undefined;
           authorizationList?: undefined;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId?: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice: bigint;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas?: undefined;
           maxPriorityFeePerGas?: undefined;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "legacy";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity?: undefined;
         }
           | {
           accessList: AccessList;
           authorizationList?: undefined;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice: bigint;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas?: undefined;
           maxPriorityFeePerGas?: undefined;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip2930";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList: AccessList;
           authorizationList?: undefined;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip1559";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList: AccessList;
           authorizationList?: undefined;
           blobVersionedHashes: readonly `0x${string}`[];
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas: bigint;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip4844";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
         }
           | {
           accessList: AccessList;
           authorizationList: SignedAuthorizationList<number>;
           blobVersionedHashes?: undefined;
           blockHash: `0x${string}` | null;
           blockNumber: bigint | null;
           chainId: number;
           from: `0x${string}`;
           gas: bigint;
           gasPrice?: undefined;
           hash: `0x${string}`;
           input: `0x${string}`;
           isSystemTx?: undefined;
           maxFeePerBlobGas?: undefined;
           maxFeePerGas: bigint;
           maxPriorityFeePerGas: bigint;
           mint?: undefined;
           nonce: number;
           r: `0x${string}`;
           s: `0x${string}`;
           sourceHash?: undefined;
           to: `0x${string}` | null;
           transactionIndex: number | null;
           type: "eip7702";
           typeHex: `0x${string}` | null;
           v: bigint;
           value: bigint;
           yParity: number;
        };
        type: "transaction";
     };
     transactionReceipt: {
        exclude: [] | undefined;
        format: (args, action?) => object;
        type: "transactionReceipt";
     };
  };
  id: 8453;
  name: "Base";
  nativeCurrency: {
     decimals: 18;
     name: "Ether";
     symbol: "ETH";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://mainnet.base.org"];
     };
  };
  serializers: {
     transaction: (transaction, signature?) => 
        | `0x02${string}`
        | `0x01${string}`
        | `0x03${string}`
        | `0x04${string}`
        | TransactionSerializedLegacy
       | `0x7e${string}`;
  };
  sourceId: 1;
  testnet?: boolean;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
```

### blockExplorers

```ts
blockExplorers: object;
```

#### blockExplorers.default

```ts
readonly default: object;
```

#### blockExplorers.default.apiUrl

```ts
readonly apiUrl: "https://api.basescan.org/api";
```

#### blockExplorers.default.name

```ts
readonly name: "Basescan";
```

#### blockExplorers.default.url

```ts
readonly url: "https://basescan.org";
```

### blockTime

```ts
blockTime: 2000;
```

### contracts

```ts
contracts: object;
```

#### contracts.disputeGameFactory

```ts
readonly disputeGameFactory: object;
```

#### contracts.disputeGameFactory.1

```ts
readonly 1: object;
```

#### contracts.disputeGameFactory.1.address

```ts
readonly address: "0x43edB88C4B80fDD2AdFF2412A7BebF9dF42cB40e";
```

#### contracts.gasPriceOracle

```ts
readonly gasPriceOracle: object;
```

#### contracts.gasPriceOracle.address

```ts
readonly address: "0x420000000000000000000000000000000000000F";
```

#### contracts.l1Block

```ts
readonly l1Block: object;
```

#### contracts.l1Block.address

```ts
readonly address: "0x4200000000000000000000000000000000000015";
```

#### contracts.l1StandardBridge

```ts
readonly l1StandardBridge: object;
```

#### contracts.l1StandardBridge.1

```ts
readonly 1: object;
```

#### contracts.l1StandardBridge.1.address

```ts
readonly address: "0x3154Cf16ccdb4C6d922629664174b904d80F2C35";
```

#### contracts.l1StandardBridge.1.blockCreated

```ts
readonly blockCreated: 17482143;
```

#### contracts.l2CrossDomainMessenger

```ts
readonly l2CrossDomainMessenger: object;
```

#### contracts.l2CrossDomainMessenger.address

```ts
readonly address: "0x4200000000000000000000000000000000000007";
```

#### contracts.l2Erc721Bridge

```ts
readonly l2Erc721Bridge: object;
```

#### contracts.l2Erc721Bridge.address

```ts
readonly address: "0x4200000000000000000000000000000000000014";
```

#### contracts.l2OutputOracle

```ts
readonly l2OutputOracle: object;
```

#### contracts.l2OutputOracle.1

```ts
readonly 1: object;
```

#### contracts.l2OutputOracle.1.address

```ts
readonly address: "0x56315b90c40730925ec5485cf004d835058518A0";
```

#### contracts.l2StandardBridge

```ts
readonly l2StandardBridge: object;
```

#### contracts.l2StandardBridge.address

```ts
readonly address: "0x4200000000000000000000000000000000000010";
```

#### contracts.l2ToL1MessagePasser

```ts
readonly l2ToL1MessagePasser: object;
```

#### contracts.l2ToL1MessagePasser.address

```ts
readonly address: "0x4200000000000000000000000000000000000016";
```

#### contracts.multicall3

```ts
readonly multicall3: object;
```

#### contracts.multicall3.address

```ts
readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
```

#### contracts.multicall3.blockCreated

```ts
readonly blockCreated: 5022;
```

#### contracts.portal

```ts
readonly portal: object;
```

#### contracts.portal.1

```ts
readonly 1: object;
```

#### contracts.portal.1.address

```ts
readonly address: "0x49048044D57e1C92A77f79988d21Fa8fAF74E97e";
```

#### contracts.portal.1.blockCreated

```ts
readonly blockCreated: 17482143;
```

### custom?

```ts
optional custom: Record<string, unknown>;
```

### ensTlds?

```ts
optional ensTlds: readonly string[];
```

### experimental\_preconfirmationTime?

```ts
optional experimental_preconfirmationTime: number;
```

### extendSchema?

```ts
optional extendSchema: Record<string, unknown>;
```

### fees?

```ts
optional fees: ChainFees<undefined>;
```

### formatters

```ts
formatters: object;
```

#### formatters.block

```ts
readonly block: object;
```

#### formatters.block.exclude

```ts
exclude: [] | undefined;
```

#### formatters.block.format()

```ts
format: (args, action?) => object;
```

##### Parameters

###### args

`OpStackRpcBlock`\<`BlockTag`, `boolean`\>

###### action?

`string`

##### Returns

`object`

###### baseFeePerGas

```ts
baseFeePerGas: bigint | null;
```

###### blobGasUsed

```ts
blobGasUsed: bigint;
```

###### difficulty

```ts
difficulty: bigint;
```

###### excessBlobGas

```ts
excessBlobGas: bigint;
```

###### extraData

```ts
extraData: `0x${string}`;
```

###### gasLimit

```ts
gasLimit: bigint;
```

###### gasUsed

```ts
gasUsed: bigint;
```

###### hash

```ts
hash: `0x${string}` | null;
```

###### logsBloom

```ts
logsBloom: `0x${string}` | null;
```

###### miner

```ts
miner: `0x${string}`;
```

###### mixHash

```ts
mixHash: `0x${string}`;
```

###### nonce

```ts
nonce: `0x${string}` | null;
```

###### number

```ts
number: bigint | null;
```

###### parentBeaconBlockRoot?

```ts
optional parentBeaconBlockRoot: `0x${string}`;
```

###### parentHash

```ts
parentHash: `0x${string}`;
```

###### receiptsRoot

```ts
receiptsRoot: `0x${string}`;
```

###### sealFields

```ts
sealFields: `0x${string}`[];
```

###### sha3Uncles

```ts
sha3Uncles: `0x${string}`;
```

###### size

```ts
size: bigint;
```

###### stateRoot

```ts
stateRoot: `0x${string}`;
```

###### timestamp

```ts
timestamp: bigint;
```

###### totalDifficulty

```ts
totalDifficulty: bigint | null;
```

###### transactions

```ts
transactions: `0x${string}`[] | OpStackTransaction<boolean>[];
```

###### transactionsRoot

```ts
transactionsRoot: `0x${string}`;
```

###### uncles

```ts
uncles: `0x${string}`[];
```

###### withdrawals?

```ts
optional withdrawals: Withdrawal[];
```

###### withdrawalsRoot?

```ts
optional withdrawalsRoot: `0x${string}`;
```

#### formatters.block.type

```ts
type: "block";
```

#### formatters.transaction

```ts
readonly transaction: object;
```

#### formatters.transaction.exclude

```ts
exclude: [] | undefined;
```

#### formatters.transaction.format()

```ts
format: (args, action?) => 
  | {
  blockHash: `0x${string}` | null;
  blockNumber: bigint | null;
  from: `0x${string}`;
  gas: bigint;
  gasPrice?: undefined;
  hash: `0x${string}`;
  input: `0x${string}`;
  isSystemTx?: boolean;
  maxFeePerBlobGas?: undefined;
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
  mint?: bigint;
  nonce: number;
  r: `0x${string}`;
  s: `0x${string}`;
  sourceHash: `0x${string}`;
  to: `0x${string}` | null;
  transactionIndex: number | null;
  type: "deposit";
  typeHex: `0x${string}` | null;
  v: bigint;
  value: bigint;
  yParity: number;
}
  | {
  accessList?: undefined;
  authorizationList?: undefined;
  blobVersionedHashes?: undefined;
  blockHash: `0x${string}` | null;
  blockNumber: bigint | null;
  chainId?: number;
  from: `0x${string}`;
  gas: bigint;
  gasPrice: bigint;
  hash: `0x${string}`;
  input: `0x${string}`;
  isSystemTx?: undefined;
  maxFeePerBlobGas?: undefined;
  maxFeePerGas?: undefined;
  maxPriorityFeePerGas?: undefined;
  mint?: undefined;
  nonce: number;
  r: `0x${string}`;
  s: `0x${string}`;
  sourceHash?: undefined;
  to: `0x${string}` | null;
  transactionIndex: number | null;
  type: "legacy";
  typeHex: `0x${string}` | null;
  v: bigint;
  value: bigint;
  yParity?: undefined;
}
  | {
  accessList: AccessList;
  authorizationList?: undefined;
  blobVersionedHashes?: undefined;
  blockHash: `0x${string}` | null;
  blockNumber: bigint | null;
  chainId: number;
  from: `0x${string}`;
  gas: bigint;
  gasPrice: bigint;
  hash: `0x${string}`;
  input: `0x${string}`;
  isSystemTx?: undefined;
  maxFeePerBlobGas?: undefined;
  maxFeePerGas?: undefined;
  maxPriorityFeePerGas?: undefined;
  mint?: undefined;
  nonce: number;
  r: `0x${string}`;
  s: `0x${string}`;
  sourceHash?: undefined;
  to: `0x${string}` | null;
  transactionIndex: number | null;
  type: "eip2930";
  typeHex: `0x${string}` | null;
  v: bigint;
  value: bigint;
  yParity: number;
}
  | {
  accessList: AccessList;
  authorizationList?: undefined;
  blobVersionedHashes?: undefined;
  blockHash: `0x${string}` | null;
  blockNumber: bigint | null;
  chainId: number;
  from: `0x${string}`;
  gas: bigint;
  gasPrice?: undefined;
  hash: `0x${string}`;
  input: `0x${string}`;
  isSystemTx?: undefined;
  maxFeePerBlobGas?: undefined;
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
  mint?: undefined;
  nonce: number;
  r: `0x${string}`;
  s: `0x${string}`;
  sourceHash?: undefined;
  to: `0x${string}` | null;
  transactionIndex: number | null;
  type: "eip1559";
  typeHex: `0x${string}` | null;
  v: bigint;
  value: bigint;
  yParity: number;
}
  | {
  accessList: AccessList;
  authorizationList?: undefined;
  blobVersionedHashes: readonly `0x${string}`[];
  blockHash: `0x${string}` | null;
  blockNumber: bigint | null;
  chainId: number;
  from: `0x${string}`;
  gas: bigint;
  gasPrice?: undefined;
  hash: `0x${string}`;
  input: `0x${string}`;
  isSystemTx?: undefined;
  maxFeePerBlobGas: bigint;
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
  mint?: undefined;
  nonce: number;
  r: `0x${string}`;
  s: `0x${string}`;
  sourceHash?: undefined;
  to: `0x${string}` | null;
  transactionIndex: number | null;
  type: "eip4844";
  typeHex: `0x${string}` | null;
  v: bigint;
  value: bigint;
  yParity: number;
}
  | {
  accessList: AccessList;
  authorizationList: SignedAuthorizationList<number>;
  blobVersionedHashes?: undefined;
  blockHash: `0x${string}` | null;
  blockNumber: bigint | null;
  chainId: number;
  from: `0x${string}`;
  gas: bigint;
  gasPrice?: undefined;
  hash: `0x${string}`;
  input: `0x${string}`;
  isSystemTx?: undefined;
  maxFeePerBlobGas?: undefined;
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
  mint?: undefined;
  nonce: number;
  r: `0x${string}`;
  s: `0x${string}`;
  sourceHash?: undefined;
  to: `0x${string}` | null;
  transactionIndex: number | null;
  type: "eip7702";
  typeHex: `0x${string}` | null;
  v: bigint;
  value: bigint;
  yParity: number;
};
```

##### Parameters

###### args

`OpStackRpcTransaction`\<`boolean`\>

###### action?

`string`

##### Returns

  \| \{
  `blockHash`: `` `0x${string}` `` \| `null`;
  `blockNumber`: `bigint` \| `null`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `isSystemTx?`: `boolean`;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `mint?`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `sourceHash`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `number` \| `null`;
  `type`: `"deposit"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList?`: `undefined`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `` `0x${string}` `` \| `null`;
  `blockNumber`: `bigint` \| `null`;
  `chainId?`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `isSystemTx?`: `undefined`;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `mint?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `sourceHash?`: `undefined`;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `number` \| `null`;
  `type`: `"legacy"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity?`: `undefined`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `` `0x${string}` `` \| `null`;
  `blockNumber`: `bigint` \| `null`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `isSystemTx?`: `undefined`;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `mint?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `sourceHash?`: `undefined`;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `number` \| `null`;
  `type`: `"eip2930"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `` `0x${string}` `` \| `null`;
  `blockNumber`: `bigint` \| `null`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `isSystemTx?`: `undefined`;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `mint?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `sourceHash?`: `undefined`;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `number` \| `null`;
  `type`: `"eip1559"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes`: readonly `` `0x${string}` ``[];
  `blockHash`: `` `0x${string}` `` \| `null`;
  `blockNumber`: `bigint` \| `null`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `isSystemTx?`: `undefined`;
  `maxFeePerBlobGas`: `bigint`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `mint?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `sourceHash?`: `undefined`;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `number` \| `null`;
  `type`: `"eip4844"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList`: `SignedAuthorizationList`\<`number`\>;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `` `0x${string}` `` \| `null`;
  `blockNumber`: `bigint` \| `null`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `isSystemTx?`: `undefined`;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `mint?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `sourceHash?`: `undefined`;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `number` \| `null`;
  `type`: `"eip7702"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}

#### formatters.transaction.type

```ts
type: "transaction";
```

#### formatters.transactionReceipt

```ts
readonly transactionReceipt: object;
```

#### formatters.transactionReceipt.exclude

```ts
exclude: [] | undefined;
```

#### formatters.transactionReceipt.format()

```ts
format: (args, action?) => object;
```

##### Parameters

###### args

`OpStackRpcTransactionReceipt`

###### action?

`string`

##### Returns

`object`

###### blobGasPrice?

```ts
optional blobGasPrice: bigint;
```

###### blobGasUsed?

```ts
optional blobGasUsed: bigint;
```

###### blockHash

```ts
blockHash: `0x${string}`;
```

###### blockNumber

```ts
blockNumber: bigint;
```

###### blockTimestamp?

```ts
optional blockTimestamp: bigint;
```

###### contractAddress

```ts
contractAddress: `0x${string}` | null | undefined;
```

###### cumulativeGasUsed

```ts
cumulativeGasUsed: bigint;
```

###### effectiveGasPrice

```ts
effectiveGasPrice: bigint;
```

###### from

```ts
from: `0x${string}`;
```

###### gasUsed

```ts
gasUsed: bigint;
```

###### l1Fee

```ts
l1Fee: bigint | null;
```

###### l1FeeScalar

```ts
l1FeeScalar: number | null;
```

###### l1GasPrice

```ts
l1GasPrice: bigint | null;
```

###### l1GasUsed

```ts
l1GasUsed: bigint | null;
```

###### logs

```ts
logs: Log<bigint, number, false, undefined, undefined, undefined, undefined>[];
```

###### logsBloom

```ts
logsBloom: `0x${string}`;
```

###### root?

```ts
optional root: `0x${string}`;
```

###### status

```ts
status: "success" | "reverted";
```

###### to

```ts
to: `0x${string}` | null;
```

###### transactionHash

```ts
transactionHash: `0x${string}`;
```

###### transactionIndex

```ts
transactionIndex: number;
```

###### type

```ts
type: TransactionType;
```

#### formatters.transactionReceipt.type

```ts
type: "transactionReceipt";
```

### id

```ts
id: 8453;
```

### name

```ts
name: "Base";
```

### nativeCurrency

```ts
nativeCurrency: object;
```

#### nativeCurrency.decimals

```ts
readonly decimals: 18;
```

#### nativeCurrency.name

```ts
readonly name: "Ether";
```

#### nativeCurrency.symbol

```ts
readonly symbol: "ETH";
```

### prepareTransactionRequest?

```ts
optional prepareTransactionRequest: 
  | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
  | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
```

### rpcUrls

```ts
rpcUrls: object;
```

#### rpcUrls.default

```ts
readonly default: object;
```

#### rpcUrls.default.http

```ts
readonly http: readonly ["https://mainnet.base.org"];
```

### serializers

```ts
serializers: object;
```

#### serializers.transaction()

```ts
readonly transaction: (transaction, signature?) => 
  | `0x02${string}`
  | `0x01${string}`
  | `0x03${string}`
  | `0x04${string}`
  | TransactionSerializedLegacy
  | `0x7e${string}`;
```

##### Parameters

###### transaction

`OpStackTransactionSerializable`

###### signature?

`Signature`

##### Returns

  \| `` `0x02${string}` ``
  \| `` `0x01${string}` ``
  \| `` `0x03${string}` ``
  \| `` `0x04${string}` ``
  \| `TransactionSerializedLegacy`
  \| `` `0x7e${string}` ``

### sourceId

```ts
sourceId: 1;
```

### testnet?

```ts
optional testnet: boolean;
```

### verifyHash()?

```ts
optional verifyHash: (client, parameters) => Promise<boolean>;
```

#### Parameters

##### client

`Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `undefined`, 
  \| \{
\[`key`: `string`\]: `unknown`;
  `account?`: `undefined`;
  `batch?`: `undefined`;
  `cacheTime?`: `undefined`;
  `ccipRead?`: `undefined`;
  `chain?`: `undefined`;
  `dataSuffix?`: `undefined`;
  `experimental_blockTag?`: `undefined`;
  `key?`: `undefined`;
  `name?`: `undefined`;
  `pollingInterval?`: `undefined`;
  `request?`: `undefined`;
  `transport?`: `undefined`;
  `type?`: `undefined`;
  `uid?`: `undefined`;
\}
  \| `undefined`\>

##### parameters

`VerifyHashParameters`

#### Returns

`Promise`\<`boolean`\>

```ts
{
  blockExplorers: {
     default: {
        apiUrl: "https://api.etherscan.io/api";
        name: "Etherscan";
        url: "https://etherscan.io";
     };
  };
  blockTime: 12000;
  contracts: {
     ensUniversalResolver: {
        address: "0xeeeeeeee14d718c2b47d9923deab1335e144eeee";
        blockCreated: 23085558;
     };
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 14353601;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 1;
  name: "Ethereum";
  nativeCurrency: {
     decimals: 18;
     name: "Ether";
     symbol: "ETH";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://eth.merkle.io"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
  sourceId?: number;
  testnet?: boolean;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
```

### blockExplorers

```ts
blockExplorers: object;
```

#### blockExplorers.default

```ts
readonly default: object;
```

#### blockExplorers.default.apiUrl

```ts
readonly apiUrl: "https://api.etherscan.io/api";
```

#### blockExplorers.default.name

```ts
readonly name: "Etherscan";
```

#### blockExplorers.default.url

```ts
readonly url: "https://etherscan.io";
```

### blockTime

```ts
blockTime: 12000;
```

### contracts

```ts
contracts: object;
```

#### contracts.ensUniversalResolver

```ts
readonly ensUniversalResolver: object;
```

#### contracts.ensUniversalResolver.address

```ts
readonly address: "0xeeeeeeee14d718c2b47d9923deab1335e144eeee";
```

#### contracts.ensUniversalResolver.blockCreated

```ts
readonly blockCreated: 23085558;
```

#### contracts.multicall3

```ts
readonly multicall3: object;
```

#### contracts.multicall3.address

```ts
readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
```

#### contracts.multicall3.blockCreated

```ts
readonly blockCreated: 14353601;
```

### custom?

```ts
optional custom: Record<string, unknown>;
```

### ensTlds?

```ts
optional ensTlds: readonly string[];
```

### experimental\_preconfirmationTime?

```ts
optional experimental_preconfirmationTime: number;
```

### extendSchema?

```ts
optional extendSchema: Record<string, unknown>;
```

### fees?

```ts
optional fees: ChainFees<undefined>;
```

### formatters?

```ts
optional formatters: undefined;
```

### id

```ts
id: 1;
```

### name

```ts
name: "Ethereum";
```

### nativeCurrency

```ts
nativeCurrency: object;
```

#### nativeCurrency.decimals

```ts
readonly decimals: 18;
```

#### nativeCurrency.name

```ts
readonly name: "Ether";
```

#### nativeCurrency.symbol

```ts
readonly symbol: "ETH";
```

### prepareTransactionRequest?

```ts
optional prepareTransactionRequest: 
  | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
  | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
```

### rpcUrls

```ts
rpcUrls: object;
```

#### rpcUrls.default

```ts
readonly default: object;
```

#### rpcUrls.default.http

```ts
readonly http: readonly ["https://eth.merkle.io"];
```

### serializers?

```ts
optional serializers: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
```

### sourceId?

```ts
optional sourceId: number;
```

### testnet?

```ts
optional testnet: boolean;
```

### verifyHash()?

```ts
optional verifyHash: (client, parameters) => Promise<boolean>;
```

#### Parameters

##### client

`Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `undefined`, 
  \| \{
\[`key`: `string`\]: `unknown`;
  `account?`: `undefined`;
  `batch?`: `undefined`;
  `cacheTime?`: `undefined`;
  `ccipRead?`: `undefined`;
  `chain?`: `undefined`;
  `dataSuffix?`: `undefined`;
  `experimental_blockTag?`: `undefined`;
  `key?`: `undefined`;
  `name?`: `undefined`;
  `pollingInterval?`: `undefined`;
  `request?`: `undefined`;
  `transport?`: `undefined`;
  `type?`: `undefined`;
  `uid?`: `undefined`;
\}
  \| `undefined`\>

##### parameters

`VerifyHashParameters`

#### Returns

`Promise`\<`boolean`\>

```ts
{
  blockExplorers: {
     default: {
        apiUrl: "https://api.arbiscan.io/api";
        name: "Arbiscan";
        url: "https://arbiscan.io";
     };
  };
  blockTime: 250;
  contracts: {
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 7654707;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 42161;
  name: "Arbitrum One";
  nativeCurrency: {
     decimals: 18;
     name: "Ether";
     symbol: "ETH";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://arb1.arbitrum.io/rpc"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
  sourceId?: number;
  testnet?: boolean;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
```

### blockExplorers

```ts
blockExplorers: object;
```

#### blockExplorers.default

```ts
readonly default: object;
```

#### blockExplorers.default.apiUrl

```ts
readonly apiUrl: "https://api.arbiscan.io/api";
```

#### blockExplorers.default.name

```ts
readonly name: "Arbiscan";
```

#### blockExplorers.default.url

```ts
readonly url: "https://arbiscan.io";
```

### blockTime

```ts
blockTime: 250;
```

### contracts

```ts
contracts: object;
```

#### contracts.multicall3

```ts
readonly multicall3: object;
```

#### contracts.multicall3.address

```ts
readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
```

#### contracts.multicall3.blockCreated

```ts
readonly blockCreated: 7654707;
```

### custom?

```ts
optional custom: Record<string, unknown>;
```

### ensTlds?

```ts
optional ensTlds: readonly string[];
```

### experimental\_preconfirmationTime?

```ts
optional experimental_preconfirmationTime: number;
```

### extendSchema?

```ts
optional extendSchema: Record<string, unknown>;
```

### fees?

```ts
optional fees: ChainFees<undefined>;
```

### formatters?

```ts
optional formatters: undefined;
```

### id

```ts
id: 42161;
```

### name

```ts
name: "Arbitrum One";
```

### nativeCurrency

```ts
nativeCurrency: object;
```

#### nativeCurrency.decimals

```ts
readonly decimals: 18;
```

#### nativeCurrency.name

```ts
readonly name: "Ether";
```

#### nativeCurrency.symbol

```ts
readonly symbol: "ETH";
```

### prepareTransactionRequest?

```ts
optional prepareTransactionRequest: 
  | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
  | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
```

### rpcUrls

```ts
rpcUrls: object;
```

#### rpcUrls.default

```ts
readonly default: object;
```

#### rpcUrls.default.http

```ts
readonly http: readonly ["https://arb1.arbitrum.io/rpc"];
```

### serializers?

```ts
optional serializers: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
```

### sourceId?

```ts
optional sourceId: number;
```

### testnet?

```ts
optional testnet: boolean;
```

### verifyHash()?

```ts
optional verifyHash: (client, parameters) => Promise<boolean>;
```

#### Parameters

##### client

`Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `undefined`, 
  \| \{
\[`key`: `string`\]: `unknown`;
  `account?`: `undefined`;
  `batch?`: `undefined`;
  `cacheTime?`: `undefined`;
  `ccipRead?`: `undefined`;
  `chain?`: `undefined`;
  `dataSuffix?`: `undefined`;
  `experimental_blockTag?`: `undefined`;
  `key?`: `undefined`;
  `name?`: `undefined`;
  `pollingInterval?`: `undefined`;
  `request?`: `undefined`;
  `transport?`: `undefined`;
  `type?`: `undefined`;
  `uid?`: `undefined`;
\}
  \| `undefined`\>

##### parameters

`VerifyHashParameters`

#### Returns

`Promise`\<`boolean`\>

```ts
{
  blockExplorers: {
     default: {
        name: "Sonic Explorer";
        url: "https://sonicscan.org";
     };
  };
  blockTime: 630;
  contracts: {
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 60;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 146;
  name: "Sonic";
  nativeCurrency: {
     decimals: 18;
     name: "Sonic";
     symbol: "S";
  };
  prepareTransactionRequest?:   | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
     | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
  rpcUrls: {
     default: {
        http: readonly ["https://rpc.soniclabs.com"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
  sourceId?: number;
  testnet: false;
  verifyHash?: (client, parameters) => Promise<boolean>;
}
```

### blockExplorers

```ts
blockExplorers: object;
```

#### blockExplorers.default

```ts
readonly default: object;
```

#### blockExplorers.default.name

```ts
readonly name: "Sonic Explorer";
```

#### blockExplorers.default.url

```ts
readonly url: "https://sonicscan.org";
```

### blockTime

```ts
blockTime: 630;
```

### contracts

```ts
contracts: object;
```

#### contracts.multicall3

```ts
readonly multicall3: object;
```

#### contracts.multicall3.address

```ts
readonly address: "0xca11bde05977b3631167028862be2a173976ca11";
```

#### contracts.multicall3.blockCreated

```ts
readonly blockCreated: 60;
```

### custom?

```ts
optional custom: Record<string, unknown>;
```

### ensTlds?

```ts
optional ensTlds: readonly string[];
```

### experimental\_preconfirmationTime?

```ts
optional experimental_preconfirmationTime: number;
```

### extendSchema?

```ts
optional extendSchema: Record<string, unknown>;
```

### fees?

```ts
optional fees: ChainFees<undefined>;
```

### formatters?

```ts
optional formatters: undefined;
```

### id

```ts
id: 146;
```

### name

```ts
name: "Sonic";
```

### nativeCurrency

```ts
nativeCurrency: object;
```

#### nativeCurrency.decimals

```ts
readonly decimals: 18;
```

#### nativeCurrency.name

```ts
readonly name: "Sonic";
```

#### nativeCurrency.symbol

```ts
readonly symbol: "S";
```

### prepareTransactionRequest?

```ts
optional prepareTransactionRequest: 
  | (args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>
  | [(args, options) => Promise<PrepareTransactionRequestParameters<Chain | undefined, Account | undefined, Chain | undefined, `0x${string}` | Account | undefined, PrepareTransactionRequestRequest<Chain | undefined, Chain | undefined, Chain | undefined>>>, object];
```

### rpcUrls

```ts
rpcUrls: object;
```

#### rpcUrls.default

```ts
readonly default: object;
```

#### rpcUrls.default.http

```ts
readonly http: readonly ["https://rpc.soniclabs.com"];
```

### serializers?

```ts
optional serializers: ChainSerializers<undefined, TransactionSerializable<bigint, number>>;
```

### sourceId?

```ts
optional sourceId: number;
```

### testnet

```ts
testnet: false;
```

### verifyHash()?

```ts
optional verifyHash: (client, parameters) => Promise<boolean>;
```

#### Parameters

##### client

`Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `undefined`, 
  \| \{
\[`key`: `string`\]: `unknown`;
  `account?`: `undefined`;
  `batch?`: `undefined`;
  `cacheTime?`: `undefined`;
  `ccipRead?`: `undefined`;
  `chain?`: `undefined`;
  `dataSuffix?`: `undefined`;
  `experimental_blockTag?`: `undefined`;
  `key?`: `undefined`;
  `name?`: `undefined`;
  `pollingInterval?`: `undefined`;
  `request?`: `undefined`;
  `transport?`: `undefined`;
  `type?`: `undefined`;
  `uid?`: `undefined`;
\}
  \| `undefined`\>

##### parameters

`VerifyHashParameters`

#### Returns

`Promise`\<`boolean`\>

```ts
{
  blockExplorers: {
     default: {
        apiUrl: "https://api.hyperevmscan.io/api";
        name: "HyperEVMScan";
        url: "https://hyperevmscan.io";
     };
  };
  blockTime?: number;
  contracts: {
     multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11";
        blockCreated: 13051;
     };
  };
  custom?: Record<string, unknown>;
  ensTlds?: readonly string[];
  experimental_preconfirmationTime?: number;
  extendSchema?: Record<string, unknown>;
  fees?: ChainFees<undefined>;
  formatters?: undefined;
  id: 999;
  name: "HyperEVM";
  nativeCurrency: {
     decimals: 18;
     name: "HYPE";
     symbol: "HYPE";
  };
  prepareTransactionRequest?:   | PrepareTransactionRequestFn
     | [PrepareTransactionRequestFn, object];
  rpcUrls: {
     default: {
        http: readonly ["https://rpc.hyperliquid.xyz/evm"];
     };
  };
  serializers?: ChainSerializers<undefined, TransactionSerializable>;
  sourceId?: number;
  testnet?: boolean;
  verifyHash?: ChainVerifyHashFn;
}
```

### blockExplorers

```ts
blockExplorers: object;
```

Collection of block explorers

#### blockExplorers.default

```ts
readonly default: object;
```

#### blockExplorers.default.apiUrl

```ts
readonly apiUrl: "https://api.hyperevmscan.io/api" = 'https://api.hyperevmscan.io/api';
```

#### blockExplorers.default.name

```ts
readonly name: "HyperEVMScan" = 'HyperEVMScan';
```

#### blockExplorers.default.url

```ts
readonly url: "https://hyperevmscan.io" = 'https://hyperevmscan.io';
```

### blockTime?

```ts
optional blockTime: number;
```

Block time in milliseconds.

### contracts

```ts
contracts: object;
```

Collection of contracts

#### contracts.multicall3

```ts
readonly multicall3: object;
```

#### contracts.multicall3.address

```ts
readonly address: "0xca11bde05977b3631167028862be2a173976ca11" = '0xca11bde05977b3631167028862be2a173976ca11';
```

#### contracts.multicall3.blockCreated

```ts
readonly blockCreated: 13051 = 13051;
```

### ~~custom?~~

```ts
optional custom: Record<string, unknown>;
```

Custom chain data.

#### Deprecated

use `.extend` instead.

### ensTlds?

```ts
optional ensTlds: readonly string[];
```

Collection of ENS TLDs for the chain.

### experimental\_preconfirmationTime?

```ts
optional experimental_preconfirmationTime: number;
```

Preconfirmation time in milliseconds.

### extendSchema?

```ts
optional extendSchema: Record<string, unknown>;
```

Extend schema.

### fees?

```ts
optional fees: ChainFees<undefined>;
```

Modifies how fees are derived.

### formatters?

```ts
optional formatters: undefined;
```

Modifies how data is formatted and typed (e.g. blocks and transactions)

### id

```ts
id: 999;
```

ID in number form

### name

```ts
name: "HyperEVM";
```

Human-readable name

### nativeCurrency

```ts
nativeCurrency: object;
```

Currency used by chain

#### nativeCurrency.decimals

```ts
readonly decimals: 18 = 18;
```

#### nativeCurrency.name

```ts
readonly name: "HYPE" = 'HYPE';
```

#### nativeCurrency.symbol

```ts
readonly symbol: "HYPE" = 'HYPE';
```

### prepareTransactionRequest?

```ts
optional prepareTransactionRequest: 
  | PrepareTransactionRequestFn
  | [PrepareTransactionRequestFn, object];
```

Function to prepare a transaction request. Runs before the transaction is filled.

### rpcUrls

```ts
rpcUrls: object;
```

Collection of RPC endpoints

#### rpcUrls.default

```ts
readonly default: object;
```

#### rpcUrls.default.http

```ts
readonly http: readonly ["https://rpc.hyperliquid.xyz/evm"];
```

### serializers?

```ts
optional serializers: ChainSerializers<undefined, TransactionSerializable>;
```

Modifies how data is serialized (e.g. transactions).

### sourceId?

```ts
optional sourceId: number;
```

Source Chain ID (ie. the L1 chain)

### testnet?

```ts
optional testnet: boolean;
```

Flag for test networks

### verifyHash?

```ts
optional verifyHash: ChainVerifyHashFn;
```

Chain-specific signature verification.
