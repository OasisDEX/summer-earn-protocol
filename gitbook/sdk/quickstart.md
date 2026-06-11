---
description: A minimal end-to-end flow — make a client, fetch a vault, build a deposit transaction.
---

# Quickstart

This page walks through the smallest useful flow: create the SDK client, look up a vault, and build
a deposit transaction ready to sign and send.

> Applies to `@summer_fi/sdk-client` v2.3.0

## 1. Create the client

```typescript
// ./sdk.ts
import { makeSDK } from '@summer_fi/sdk-client'

export const sdk = makeSDK({
  apiDomainUrl: `https://summer.fi`,
  logging: process.env.NODE_ENV === 'development',
})
```

See [Overview](overview.md) for the full client surface, or the
[`makeSDK`](reference/@summerfi/sdk-client/functions/makeSDK.md) reference.

## 2. Fetch a vault

List all vaults on a chain, then pick one. Each entry's `id` is an
[`ArmadaVaultId`](reference/@summerfi/sdk-client/classes/ArmadaVaultId.md) you can reuse.

```typescript
import { ChainIds } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const vaults = await sdk.armada.users.getVaultInfoList({ chainId: ChainIds.Base })
const vaultInfo = vaults.list[0]

console.log('Vault:', vaultInfo.id.toString(), vaultInfo.apy?.toString())
```

## 3. Build a deposit transaction

Create a user, a vault ID, a token amount, and a slippage tolerance, then ask the SDK for the
deposit transaction(s). The result is an array containing the deposit transaction, optionally
preceded by an approval transaction.

```typescript
import {
  ArmadaVaultId,
  ChainIds,
  User,
  Address,
  TokenAmount,
  Percentage,
} from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const user = User.createFromEthereum(ChainIds.Base, '0x...')

const vaultId = ArmadaVaultId.createFrom({
  chainInfo: user.chainInfo,
  fleetAddress: Address.createFromEthereum({ value: '0x...' }),
})

const token = await sdk.tokens.getTokenBySymbol({ symbol: 'ETH', chainId: user.chainInfo.chainId })

const amount = TokenAmount.createFrom({ amount: '1', token }) // full units, e.g. 1 ETH

const slippage = Percentage.createFrom({ value: '0.5' }) // 0.5%

const transactions = await sdk.armada.users.getNewDepositTx({
  vaultId,
  user,
  amount,
  slippage,
})
```

## 4. Sign and send

Send each returned transaction with your preferred web3 client (ethers, viem, wagmi). If an approval
is present, send it first.

```typescript
// example using viem
const txInfo = transactions[0]
const hash = await walletClient.sendTransaction({
  to: txInfo.transaction.target.value,
  data: txInfo.transaction.calldata,
  value: BigInt(txInfo.transaction.value),
})
```

## Where to go next

- [Deposits](guides/deposits.md) — full deposit flow, including approvals and swaps.
- [Cross-chain deposits](guides/cross-chain-deposits.md)
- [Withdrawals](guides/withdrawals.md)
- [Positions](guides/positions.md)
