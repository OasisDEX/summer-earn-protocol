---
description: Deposit tokens from one chain into an Armada vault on a different chain.
---

# Cross-Chain Deposits

> Applies to `@summer_fi/sdk-client` v2.3.0

`getCrossChainDepositTx` deposits tokens held on a **source** chain into a vault on a **destination**
chain, handling bridging and any required token conversion in a single flow. Introduced in v2.3.0.

## Parameters

- **fromChainId** — source chain ID where the user holds the tokens.
- **vaultId** — target [`ArmadaVaultId`](../reference/@summerfi/sdk-client/classes/ArmadaVaultId.md)
  on the destination chain.
- **senderAddressValue** — address sending the tokens (a `0x` address value).
- **receiverAddressValue** (optional) — address to receive vault shares; defaults to the sender.
- **amount** — token amount to deposit from the source chain.
- **slippage** — maximum slippage tolerance for the operation.

## Build the cross-chain deposit

```typescript
import {
  ArmadaVaultId,
  ChainIds,
  Address,
  TokenAmount,
  Percentage,
  getChainInfoByChainId,
} from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const fromChainId = ChainIds.Base
const userAddress = '0x...'

// token on the SOURCE chain
const sourceToken = await sdk.tokens.getTokenBySymbol({ symbol: 'USDC', chainId: fromChainId })

const amount = TokenAmount.createFrom({ amount: '100', token: sourceToken }) // 100 USDC from Base

// vault on the DESTINATION chain
const toChainId = ChainIds.ArbitrumOne
const vaultId = ArmadaVaultId.createFrom({
  chainInfo: getChainInfoByChainId(toChainId),
  fleetAddress: Address.createFromEthereum({ value: '0x...' }), // vault on Arbitrum
})

const slippage = Percentage.createFrom({ value: '0.5' }) // 0.5%

const transactions = await sdk.armada.users.getCrossChainDepositTx({
  fromChainId,
  vaultId,
  senderAddressValue: userAddress,
  // receiverAddressValue: '0x...', // optional: different shares receiver
  amount,
  slippage,
})
```

## Handle approval + deposit

As with single-chain deposits, the result is one or two transactions. An approval (for the source
token, e.g. spending by the router) precedes the deposit when allowance is required.

```typescript
if (transactions.length === 2) {
  const [approval, deposit] = transactions
  // execute approval first, then deposit
} else if (transactions.length === 1) {
  const [deposit] = transactions
}

// example using viem
const txInfo = transactions[0]
const hash = await walletClient.sendTransaction({
  to: txInfo.transaction.target.value,
  data: txInfo.transaction.calldata,
  value: BigInt(txInfo.transaction.value),
})
```

The `Deposit` transaction's metadata includes `fromAmount`, `toAmount`, and `slippage`, describing
the bridged conversion (for example, 100 USDC from Base becoming ~99.5 USDC into the Arbitrum vault).

## Supported routes

Cross-chain deposits are supported from Base, Arbitrum, Optimism, Mainnet, and Sonic into any
supported destination chain.
