---
description: Withdraw from a vault and switch funds between vaults.
---

# Withdrawals and Vault Switching

> Applies to `@summer_fi/sdk-client` v2.3.0

This guide covers withdrawing assets from an Armada vault and moving a position from one vault to
another.

## Withdraw

`getWithdrawTx` builds the transaction(s) to withdraw from a vault into a chosen output token. As
with deposits, `slippage` applies only when a swap is involved — that is, when `toToken` differs from
the vault's underlying asset.

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

const token = await sdk.tokens.getTokenBySymbol({ symbol: 'USDC', chainId: user.chainInfo.chainId })

// amount is in full units, e.g. 1 USDC
const amount = TokenAmount.createFrom({ amount: '1', token })

const transactions = await sdk.armada.users.getWithdrawTx({
  vaultId,
  user,
  amount,
  toToken: amount.token,
  slippage: Percentage.createFrom({ value: 1 }), // 1%
})

// sign and send each returned transaction
const txInfo = transactions[0]
const hash = await walletClient.sendTransaction({
  to: txInfo.transaction.target.value,
  data: txInfo.transaction.calldata,
  value: BigInt(txInfo.transaction.value),
})
```

The `Withdraw` transaction's metadata includes `fromAmount`, `toAmount`, an optional `priceImpact`,
and `slippage`.

## Switch vaults

`getVaultSwitchTx` moves an amount from a source vault into a destination vault in one flow.

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

const usdc = await sdk.tokens.getTokenBySymbol({ symbol: 'USDC', chainId: user.chainInfo.chainId })
const switchAmount = TokenAmount.createFrom({ amount: '10', token: usdc })

const sourceVaultId = ArmadaVaultId.createFrom({
  chainInfo: user.chainInfo,
  fleetAddress: Address.createFromEthereum({ value: '0x...' }), // source vault
})
const destinationVaultId = ArmadaVaultId.createFrom({
  chainInfo: user.chainInfo,
  fleetAddress: Address.createFromEthereum({ value: '0x...' }), // destination vault
})

const slippage = Percentage.createFrom({ value: '0.5' }) // 0.5%

const transactions = await sdk.armada.users.getVaultSwitchTx({
  sourceVaultId,
  destinationVaultId,
  amount: switchAmount,
  user,
  slippage,
})
```

A vault switch may need up to three transactions. Any leading transactions are approvals (sent only
when allowance is required); the final transaction is always the switch itself.

```typescript
if (transactions.length === 3) {
  // two approvals, then the switch
} else if (transactions.length === 2) {
  // one approval, then the switch
} else if (transactions.length === 1) {
  // switch only
}
```

The `VaultSwitch` transaction's metadata includes `fromVault`, `toVault`, `fromAmount`, `toAmount`,
an optional `priceImpact`, and `slippage`.
