---
description: Read user positions and their deposit, withdrawal, and value history.
---

# Positions

> Applies to `@summer_fi/sdk-client` v2.3.0

A position represents a user's holding in a single Armada vault. Positions are returned as
[`IArmadaPosition`](../reference/@summerfi/sdk-client/interfaces/IArmadaPosition.md) objects and
identified by an [`IArmadaPositionId`](../reference/@summerfi/sdk-client/interfaces/IArmadaPositionId.md)
of the form `{wallet_address}-{fleet_address}` (lowercase).

## Retrieve positions

```typescript
import { User, ChainIds, Address } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const user = User.createFromEthereum(ChainIds.Base, '0x...')

// all positions for the user on the chain
const positions = await sdk.armada.users.getUserPositions({ user })

// or a single position in a specific vault
const position = await sdk.armada.users.getUserPosition({
  user,
  fleetAddress: Address.createFromEthereum({ value: '0x...' }),
})

if (position) {
  console.log('Position:', {
    assets: position.assets.toString(), // current balance
    assetsUSD: position.assetsUSD.toString(), // value in USD
    shares: position.shares.toString(), // vault shares held

    depositsAmount: position.depositsAmount.toString(),
    withdrawalsAmount: position.withdrawalsAmount.toString(),

    netDeposits: position.netDeposits.toString(), // deposits - withdrawals
    earnings: position.earnings.toString(), // assets - netDeposits (profit/loss)
    earningsUSD: position.earningsUSD.toString(),

    claimableSummerToken: position.claimableSummerToken.toString(),
  })
}
```

> The `amount` property is deprecated (v1.x). Use `assets` for the current balance.

## Deposit history

`getDeposits` returns the deposit transactions for a position as
[`IArmadaDeposit`](../reference/@summerfi/sdk-client/interfaces/IArmadaPosition.md) records, ordered
newest first. Supports pagination via `first` (default 1000) and `skip` (default 0).

```typescript
import { ArmadaPositionId, User, ChainIds, Address } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const user = User.createFromEthereum(ChainIds.Base, '0x...')
const fleetAddress = Address.createFromEthereum({ value: '0x...' })

const positionId = ArmadaPositionId.createFrom({
  id: `${user.wallet.address.value.toLowerCase()}-${fleetAddress.value.toLowerCase()}`,
  user,
})

const deposits = await sdk.armada.users.getDeposits({ positionId })

// with pagination
const depositsPage = await sdk.armada.users.getDeposits({ positionId, first: 10, skip: 0 })

deposits.forEach((deposit) => {
  console.log('Deposit:', {
    from: deposit.from, // address that initiated the deposit
    to: deposit.to, // vault address
    amount: deposit.amount.toString(),
    amountUsd: deposit.amountUsd.toString(), // USD value at deposit time
    timestamp: new Date(deposit.timestamp * 1000).toISOString(),
    txHash: deposit.txHash,
    vaultBalance: deposit.vaultBalance.toString(), // total vault balance after deposit
    vaultBalanceUsd: deposit.vaultBalanceUsd.toString(),
  })
})
```

## Withdrawal history

`getWithdrawals` mirrors `getDeposits`, returning `IArmadaWithdrawal` records with the same fields
(here `from` is the vault address and `to` is the receiving address). It supports the same `first`
and `skip` pagination.

```typescript
const withdrawals = await sdk.armada.users.getWithdrawals({ positionId })

const withdrawalsPage = await sdk.armada.users.getWithdrawals({ positionId, first: 10, skip: 0 })

withdrawals.forEach((withdrawal) => {
  console.log('Withdrawal:', {
    from: withdrawal.from,
    to: withdrawal.to,
    amount: withdrawal.amount.toString(),
    amountUsd: withdrawal.amountUsd.toString(),
    timestamp: new Date(withdrawal.timestamp * 1000).toISOString(),
    txHash: withdrawal.txHash,
  })
})
```

Both methods return empty arrays for positions with no matching transactions.

## Position value history

`getPositionHistory` returns hourly, daily, and weekly snapshots of a position's value over time.

```typescript
import { sdk } from './sdk'

// derive positionId from a fetched position
const userPosition = await sdk.armada.users.getUserPosition({ user, fleetAddress })
const positionId = userPosition?.id

const history = await sdk.armada.users.getPositionHistory({ positionId })

if (history.position) {
  const latest = history.position.hourlyPositionHistory[0]
  if (latest) {
    console.log('Latest snapshot:', {
      timestamp: latest.timestamp.toString(),
      netValue: latest.netValue,
      deposits: latest.deposits,
      withdrawals: latest.withdrawals,
    })
  }

  // history.position.dailyPositionHistory and weeklyPositionHistory have the same shape
} else {
  console.log('Position not found or has no activity')
}
```

Each snapshot includes `timestamp`, `netValue`, cumulative `deposits`, and cumulative `withdrawals`.
Positions with no activity yield a `null` / empty `position`.
