---
description: Check and claim rewards, including Merkl and aggregated governance rewards.
---

# Rewards

> Applies to `@summer_fi/sdk-client` v2.3.0

The SDK exposes several reward flows: Merkl vault-usage rewards, referral-fee rewards, operator
authorization for Merkl claims, and aggregated governance rewards across chains.

## Check Merkl rewards for vault deposits

`getUserMerklRewards` returns claimable Merkl rewards for a user, organized by chain.

**Parameters:**

- **address** — the user's wallet address.
- **chainIds** (optional) — chain IDs to filter by (default: all supported chains).
- **rewardsTokensAddresses** (optional) — specific reward-token addresses to filter by.

```typescript
import { ChainIds } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

// all supported chains
const rewards = await sdk.armada.users.getUserMerklRewards({
  address: '0x742d35Cc6633C0532925a3b8D84c94f8855C4ba2',
})
console.log('Rewards per chain:', rewards.perChain)

// a specific chain
const baseRewards = await sdk.armada.users.getUserMerklRewards({
  address: '0x742d35Cc6633C0532925a3b8D84c94f8855C4ba2',
  chainIds: [ChainIds.Base],
})
```

`rewards.perChain` maps each chain ID to an array of reward entries; each entry includes the reward
`token`, the Merkl `root`, `recipient`, `amount`, `claimed`, `pending`, and the Merkl `proofs`.

## Claim Merkl rewards for vault usage

`getUserMerklClaimTx` generates a single transaction claiming all of a user's Merkl vault rewards on
a chain. It returns an array with one `MerklClaim` transaction, or `undefined` if there are no
rewards to claim.

```typescript
const claimTransactions = await sdk.armada.users.getUserMerklClaimTx({
  address: '0x742d35Cc6633C0532925a3b8D84c94f8855C4ba2',
  chainId: ChainIds.Base,
})

if (claimTransactions) {
  const tx = claimTransactions[0]
  await walletClient.sendTransaction({
    to: tx.transaction.target.value,
    data: tx.transaction.calldata,
    value: BigInt(tx.transaction.value),
  })
}
```

## Claim referral-fee rewards

`getReferralFeesMerklClaimTx` claims accrued referral fees for specific reward tokens on a chain. It
returns an array with one `MerklClaim` transaction, or `undefined` if there is nothing to claim.

```typescript
const claimTransactions = await sdk.armada.users.getReferralFeesMerklClaimTx({
  address: userAddress,
  chainId: ChainIds.Base,
  rewardsTokensAddresses: [usdcTokenAddress],
})
```

## Merkl operator authorization

Claiming Merkl rewards through the protocol requires the AdmiralsQuarters multicall contract (AQ) to
be authorized as a Merkl rewards operator for the user.

Check the current authorization status:

```typescript
import { ChainIds } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const isAuthorized = await sdk.armada.users.getIsAuthorizedAsMerklRewardsOperator({
  chainId: ChainIds.Base,
  user: '0x742d35Cc6633C0532925a3b8D84c94f8855C4ba2',
})
```

Generate a transaction to authorize AQ if needed:

```typescript
const authTransactions = await sdk.armada.users.getAuthorizeAsMerklRewardsOperatorTx({
  chainId: ChainIds.Base,
  user: '0x742d35Cc6633C0532925a3b8D84c94f8855C4ba2',
})

const tx = authTransactions[0] // type: 'ToggleAQasMerklRewardsOperator'
await walletClient.sendTransaction({
  to: tx.transaction.target.value,
  data: tx.transaction.calldata,
  value: BigInt(tx.transaction.value),
})
```

## Aggregated governance rewards

`getAggregatedRewards` returns the total governance (SUMR) rewards a user can claim across all
chains, broken down by source.

```typescript
import { User, ChainIds } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const user = User.createFromEthereum(ChainIds.Base, '0x742d35Cc6633C0532925a3b8D84c94f8855C4ba2')

const rewards = await sdk.armada.users.getAggregatedRewards({ user })

console.log('Total rewards:', rewards.total)
console.log('Vault usage per chain:', rewards.vaultUsagePerChain)
console.log('Vote delegation rewards:', rewards.voteDelegation)
```

The result breaks down into `total`, `vaultUsage` / `vaultUsagePerChain`, `merkleDistribution`,
`voteDelegation`, and `perChain`.

### Including Merkl rewards

`getAggregatedRewardsIncludingMerkl` returns the same breakdown but folds Merkl rewards into the
totals.

```typescript
const rewards = await sdk.armada.users.getAggregatedRewardsIncludingMerkl({ user })

console.log('Total (incl. Merkl):', rewards.total)
console.log('Merkle distribution:', rewards.merkleDistribution)
```
