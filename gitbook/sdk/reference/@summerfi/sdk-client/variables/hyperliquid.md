# Variable: hyperliquid

```ts
const hyperliquid: object;
```

Defined in: [sdk/sdk-common/src/common/utils/getViemChain.ts:5](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/utils/getViemChain.ts#L5)

## Type Declaration

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
