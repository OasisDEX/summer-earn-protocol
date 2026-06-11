---
description: Build a single-chain deposit transaction, including approval handling.
---

# Deposits

> Applies to `@summer_fi/sdk-client` v2.3.0

`getNewDepositTx` builds the transaction(s) needed to deposit a token into an Armada vault on the
same chain. To deposit from a different chain, see
[Cross-chain deposits](cross-chain-deposits.md).

## Build the deposit

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

// the wallet performing the deposit
const user = User.createFromEthereum(ChainIds.Base, '0x...')

// the target vault, by its fleet deployment address
const vaultId = ArmadaVaultId.createFrom({
  chainInfo: user.chainInfo,
  fleetAddress: Address.createFromEthereum({ value: '0x...' }),
})

// resolve the token you want to deposit
const token = await sdk.tokens.getTokenBySymbol({ symbol: 'ETH', chainId: user.chainInfo.chainId })

// amount is in full units, e.g. 1 ETH, 1 USDC
const amount = TokenAmount.createFrom({ amount: '1', token })

// slippage matters only when a swap is involved — i.e. when the deposited
// asset differs from the vault's underlying asset. Value is a percentage.
const slippage = Percentage.createFrom({ value: '0.5' }) // 0.5%

const transactions = await sdk.armada.users.getNewDepositTx({
  vaultId,
  user,
  amount,
  slippage,
  referralCode: 'XXXXX', // optional — for the referral program
})
```

## Handle approval + deposit

The call returns one or two transactions. If the vault needs token allowance, the first transaction
is an `Approve` and the second is the `Deposit`; otherwise a single `Deposit` is returned.

```typescript
if (transactions.length === 2) {
  const [approval, deposit] = transactions
  // approval.type === 'Approve'
  //   metadata: { approvalAmount: ITokenAmount, approvalSpender: IAddress }
  // deposit.type === 'Deposit'
  //   metadata: { fromAmount, toAmount, priceImpact?, slippage }
} else if (transactions.length === 1) {
  const [deposit] = transactions
}
```

Send the approval (if present) before the deposit. See
[Transaction types](../reference/@summerfi/sdk-client/README.md) for the `Approve` and `Deposit`
metadata shapes.

## Sign and send

```typescript
// example using viem — send each transaction in order
const txInfo = transactions[0]
const hash = await walletClient.sendTransaction({
  to: txInfo.transaction.target.value,
  data: txInfo.transaction.calldata,
  value: BigInt(txInfo.transaction.value),
})
```
