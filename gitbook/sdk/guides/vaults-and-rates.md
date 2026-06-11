---
description: Retrieve the vault list, a specific vault, and historical rate data.
---

# Vaults and Rates

> Applies to `@summer_fi/sdk-client` v2.3.0

This guide covers reading Armada vault information and historical rates. Vault info is returned as
[`IArmadaVaultInfo`](../reference/@summerfi/sdk-client/interfaces/IArmadaVaultInfo.md) objects.

## Retrieve the vault list

`getVaultInfoList` returns all vaults on a chain, including caps, totals, share price, APYs, and any
reward / Merkl emissions.

```typescript
import { ChainIds } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const chainId = ChainIds.Base
const vaults = await sdk.armada.users.getVaultInfoList({ chainId })

for (const vaultInfo of vaults.list) {
  console.log({
    id: vaultInfo.id.toString(),
    token: vaultInfo.token.toString(),
    depositCap: vaultInfo.depositCap.toString(),
    totalDeposits: vaultInfo.totalDeposits.toString(),
    totalShares: vaultInfo.totalShares.toString(),
    sharePrice: vaultInfo.sharePrice.toString(),
    apy: vaultInfo.apy?.toString(),
    apys: {
      live: vaultInfo.apys.live?.toString(),
      sma24h: vaultInfo.apys.sma24h?.toString(),
      sma7day: vaultInfo.apys.sma7day?.toString(),
      sma30day: vaultInfo.apys.sma30day?.toString(),
    },
    rewardsApys: vaultInfo.rewardsApys?.map((reward) => ({
      token: reward.token.toString(),
      apy: reward.apy?.toString(),
    })),
    merklRewards: vaultInfo.merklRewards?.map((reward) => ({
      token: reward.token.toString(),
      dailyEmission: reward.dailyEmission,
    })),
  })
}
```

### APY fields

`apys` exposes several time horizons, all nullable `IPercentage` values:

- `live` — current real-time APY
- `sma24h` — 24-hour simple moving average
- `sma7day` — 7-day simple moving average
- `sma30day` — 30-day simple moving average

`rewardsApys` lists additional reward-token APYs, and `merklRewards` (present only when a vault has
active Merkl campaigns) lists each reward token and its `dailyEmission` (in wei, as a string).

## Retrieve a specific vault

Construct an [`ArmadaVaultId`](../reference/@summerfi/sdk-client/classes/ArmadaVaultId.md) (or reuse
one from `getVaultInfoList`) and call `getVaultInfo`.

```typescript
import { ArmadaVaultId } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

// from a list result: const vaultId = vaults.list[0].id
// or construct it manually:
const vaultId = ArmadaVaultId.createFrom({
  chainInfo,
  fleetAddress: '0x...',
})

const vaultInfo = await sdk.armada.users.getVaultInfo({ vaultId })

console.log(vaultInfo.sharePrice.toString(), vaultInfo.apy?.toString())
```

The returned object has the same shape as each entry in `getVaultInfoList().list`.

## Retrieve historical rates

`getVaultsHistoricalRates` returns rate history for one or more vaults across hourly, daily, and
weekly granularities. Each fleet is identified by its `fleetAddress` and `chainId`, so you can query
vaults on different chains in a single request.

```typescript
import { ChainIds } from '@summer_fi/sdk-client'
import { sdk } from './sdk'

const historicalRates = await sdk.armada.users.getVaultsHistoricalRates({
  fleets: [
    { fleetAddress: '0x742d35Cc6633C0532925a3b8D84c94f8855C4ba2', chainId: ChainIds.Base },
    { fleetAddress: '0xa0b86a33e6d9fdb91b23dc0a4dd9a7b0d2d15a76', chainId: ChainIds.Sonic },
  ],
})

console.log(JSON.stringify(historicalRates, null, 2))
```

The response is an array of `HistoricalFleetRateResult` objects (one per requested fleet). Each
`rates` object contains:

- `dailyRates` — daily aggregated average rates
- `hourlyRates` — hourly aggregated average rates
- `weeklyRates` — weekly aggregated average rates
- `latestRate` — the most recent rate snapshot

Fleets with no recorded data return empty arrays for each granularity.
