---
description: Lambda functions that expose protocol-level statistics and integrations for external consumers, including TVL data, collateral snapshots, campaign eligibility, and claimable reward transactions.
---

# External and Protocol Integrations

This page covers Lambda functions aimed at external consumers (indexers, dashboards, campaign platforms) and reward-claim helpers. Sources span both the `external-api` and `summerfi-api` monorepo packages.

> **TODO (human input):** Confirm the API Gateway base URL(s) and any required authentication for each function. The source files do not hard-code externally visible hostnames.

---

## get-protocol-info (`external-api`)

A single Lambda that serves four distinct routes, all resolved from the same function based on the `rawPath` suffix.

### GET `/` — Protocol statistics

Returns aggregate TVL and vault counts across all supported chains, with per-chain breakdown.

#### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `chainId` | number | no | Restrict to a single chain. Omit to query all supported chains. |

#### Response `200`

```json
{
  "protocol": {
    "totalValueLockedUSD": 125000000.00,
    "totalVaults": 42
  },
  "chains": [
    {
      "chainId": 1,
      "publicVaults": { "totalValueLockedUSD": 80000000.00, "totalVaults": 20 },
      "institutionalVaults": { "totalValueLockedUSD": 45000000.00, "totalVaults": 22 },
      "totalValueLockedUSD": 125000000.00,
      "totalVaults": 42
    }
  ]
}
```

TVL is sourced from the `summer-earn-protocol-subgraph` (public vaults) and `summer-earn-institutions-subgraph` (institutional vaults). See [fleet-commander.md](../contracts/core/reference/contracts/fleet-commander.md) for the on-chain vault contract.

---

### POST `/users` (preferred) — User position details

Returns TVL and SUMMER token reward information for one or more wallet addresses.

#### Request body

```json
{
  "addresses": ["0xabc...", "0xdef..."],
  "chainId": 1
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `addresses` | string array | yes | Up to 1 000 Ethereum addresses |
| `chainId` | number | no | Restrict to a single chain. Omit to query all supported chains. |

#### GET `/users` (deprecated)

The same endpoint accepts GET with `addresses` as a comma-separated query string value and optional `chainId`. The GET form is deprecated; use POST.

#### Response `200`

```json
{
  "users": [
    {
      "address": "0xabc...",
      "totalValueLockedUSD": 5000.00,
      "rewards": {
        "unclaimed": 12.5,
        "claimed": 45.0,
        "total": 57.5
      }
    }
  ]
}
```

- `totalValueLockedUSD` — sum of `inputTokenBalanceNormalizedInUSD` across all positions.
- `rewards.unclaimed` — live balance from `FleetRewardsManager.earned()` via on-chain multicall, normalised by 10^18.
- `rewards.claimed` — sum of `claimedSummerTokenNormalized` from subgraph positions.
- `rewards.total` — `unclaimed + claimed`.

SUMMER token addresses used per chain: mainnet / Arbitrum / Base use `0x194f360D130F2393a5E9F3117A6a1B78aBEa1624`; Sonic uses `0x4e0037f487bBb588bf1B7a83BDe6c34FeD6099e3`; Hyperliquid uses `0x72c527d3efDe2169AA950EFc9573C838cf125D21`.

---

### GET `/all-users` — All protocol addresses

Returns every address that has ever interacted with the protocol, paginated internally in pages of 5 000 and de-duplicated.

#### Response `200`

```json
{
  "addresses": ["0xabc...", "0xdef..."]
}
```

---

### GET `/circulating-supply`

Returns the circulating supply of the SUMMER token. Implementation is in `src/handlers/circulating-supply.ts`.

> **TODO (human input):** The circulating-supply handler was not read as part of this documentation pass. Review `handlers/circulating-supply.ts` to document its response shape.

---

## get-collateral-locked (`external-api`)

Returns weETH / eETH collateral locked across Aave/Spark, Ajna, and (on mainnet and Base) Morpho Blue, at a specific block height.

### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `chainId` | number | yes | Chain to query (mainnet, optimism, arbitrum, base supported) |
| `blockNumber` | number | yes | Block at which to snapshot collateral |
| `address` | string | no | Comma-separated list of owner addresses to filter results. Omit to return all holders. |

### Token scope

Only weETH and eETH collateral is tracked. Token addresses are hard-coded per chain (e.g. mainnet eETH `0x35fA164735182de50811E8e2E824cFb9B6118ac2`, weETH `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee`).

### Response `200`

```json
{
  "Result": [
    { "address": "0xabc...", "effective_balance": 12.5 }
  ],
  "TVL": 8430.75
}
```

- `effective_balance` — total weETH/eETH collateral for the owner across all queried protocols, in token units (18-decimal normalised).
- `TVL` — sum of `effective_balance` across **all** owners regardless of the `address` filter.

---

## get-campaign-data (`external-api`)

Checks whether a wallet has completed a series of on-chain quests for a named campaign.

### GET `/api/campaigns/{campaign}/{questNumber}/{walletAddress}`

#### Path parameters

| Parameter | Type | Description |
|---|---|---|
| `campaign` | string | Campaign identifier. Only `okx` is supported. |
| `questNumber` | integer (1–4) | Check completion up to and including this quest number |
| `walletAddress` | address | Wallet to check |

#### Query parameters

| Parameter | Type | Description |
|---|---|---|
| `debug` | any | Include debug information in the response when present |

#### Response `200`

```json
{ "code": 0, "data": true }
```

`data` is `true` only when every quest from 1 up to `questNumber` is completed. Quests must be completed sequentially. `code` is always `0` on success. An OKX-wallet allowlist is checked first; wallets not on the list receive `{ "code": 0, "data": false }` immediately.

---

## get-migrations (`summerfi-api`)

Finds DeFi positions that are eligible for migration to the Summer.fi Earn protocol.

### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `address` | address | yes | Wallet to inspect for migratable positions |
| `chainId` | number | no | If provided, `customRpcUrl` must also be provided |
| `customRpcUrl` | URL | no | Custom RPC endpoint; must accompany `chainId` |

### Response `200`

```json
{
  "migrations": [
    { "positionAddressType": "EOA", ... }
  ],
  "migrationsV2": [
    { "positionAddressType": "EOA", ... },
    { "positionAddressType": "DPM", ... }
  ]
}
```

`migrations` contains only EOA-owned positions (legacy format). `migrationsV2` contains all eligible migrations. The shape of each `PortfolioMigration` object is defined in `@summerfi/serverless-shared/domain-types`.

---

## get-morpho-claims (`summerfi-api`)

Returns claimable Morpho Blue reward tokens for a wallet, including Merkle proofs required for on-chain claiming.

### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `account` | address | yes | Wallet address |
| `chainId` | number | yes | Numeric chain ID |
| `claimType` | `supply` or `borrow` | yes | Which reward distribution to query |

### Response `200`

```json
{
  "claimable": [
    {
      "urd": "0x...",
      "rewardTokenAddress": "0x...",
      "claimable": "1000000000000000000",
      "proof": ["0x...", "0x..."]
    }
  ],
  "claimsAggregated": [
    {
      "rewardTokenAddress": "0x...",
      "claimable": "1000000000000000000",
      "claimed": "500000000000000000",
      "accrued": "1500000000000000000"
    }
  ]
}
```

---

## spark-rewards-claim (`summerfi-api`)

Returns claimable Spark reward data and a ready-to-broadcast multicall transaction for claiming all outstanding Spark rewards in a single transaction. Operates on Ethereum mainnet only.

### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `account` | address | yes | Wallet address |

### Response `200`

```json
{
  "canClaim": true,
  "cumulativeToClaim": "2000000000000000000",
  "cumulativeClaimed": "500000000000000000",
  "claimMulticallTransaction": {
    "to": "0x...",
    "data": "0x...",
    "value": "0"
  },
  "calls": [
    { "allowFailure": true, "target": "0x...", "callData": "0x..." }
  ]
}
```

- `canClaim` — `true` when `cumulativeToClaim > cumulativeClaimed`.
- `claimMulticallTransaction` — an unsigned `aggregate3` multicall transaction targeting Ethereum's Multicall3 contract. `null` when `canClaim` is `false`.
- `calls` — the individual claim calls packed into the multicall, one per reward epoch. Also `null` when `canClaim` is `false`.
- `cumulativeToClaim` and `cumulativeClaimed` are raw uint256 strings (wei).

Reward data is fetched from the Spark rewards API; proofs and root hashes are validated against known values before the transaction is constructed.
