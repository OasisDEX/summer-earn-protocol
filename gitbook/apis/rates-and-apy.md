---
description: Lambda functions that return per-ark interest rates, historical rate series, fleet vault rates, and position APY for DeFi lending protocols.
---

# Rates and APY

Three Lambda functions serve rate and APY data:

- **get-rates-function** — per-ark (product) spot and historical interest rates, combining on-chain subgraph data with off-chain reward rates from PostgreSQL.
- **get-vault-rates-function** — per-fleet (vault) spot and historical rates with 24h / 7d / 30d simple moving averages.
- **get-apy-function** — net APY for a specific borrowing/lending position on Aave, Spark, Morpho Blue, or Ajna, accounting for supplied-token and borrowed-token price appreciation.

> **TODO (human input):** Confirm the API Gateway base URL and any required authentication headers.

---

## GET `/api/rates/{chainId}`

Returns the most recent interest rates (up to 20 data points) for a single Ark product, with native and reward components split out.

### Path parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `chainId` | string | yes | Numeric chain ID (e.g. `1` for Ethereum mainnet) |

### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `productId` | string | yes | Ark product identifier (format: `<...>-<chainId>`) |
| `withCache` | boolean | no | Pass `true` to serve from Redis if available |

### Response `200`

```json
{
  "interestRates": [
    {
      "timestamp": "1710000000",
      "rate": "0.0456",
      "nativeRate": "0.0300",
      "rewardRate": "0.0156"
    }
  ]
}
```

`rate` is the sum of `nativeRate` (from the earn-protocol subgraph) and `rewardRate` (from the reward-rate PostgreSQL table). At most 20 records are returned, newest first.

---

## GET `/api/historicalRates/{chainId}`

Returns daily, hourly, and weekly rate series plus the latest single data point for a product.

### Path and query parameters

Same as `GET /api/rates/{chainId}`.

### Response `200`

```json
{
  "dailyInterestRates": [
    { "date": "20240310", "averageRate": "0.042", "nativeRate": "0.03", "rewardRate": "0.012" }
  ],
  "hourlyInterestRates": [
    { "date": "2024031006", "averageRate": "0.041", "nativeRate": "0.03", "rewardRate": "0.011" }
  ],
  "weeklyInterestRates": [
    { "date": "20240304", "averageRate": "0.045", "nativeRate": "0.032", "rewardRate": "0.013" }
  ],
  "latestInterestRate": [
    {
      "rate": [
        { "rate": "0.0456", "rewardRate": "0.0156", "nativeRate": "0.03" }
      ]
    }
  ]
}
```

Limits: 365 daily, 720 hourly, 156 weekly records. Rates from both sources are matched by `date` key (aggregated) or within a 1-hour timestamp window (raw).

---

## POST `/api/rates`

Batch variant that fetches spot rates for multiple products across multiple chains in a single call.

### Request body

```json
{
  "productIds": [
    "aave-usdc-1",
    "aave-weth-1",
    "spark-dai-1"
  ]
}
```

`productIds` must be a non-empty array. Each ID must end with `-{chainId}` so the function can group requests by chain.

### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `withCache` | boolean | no | Serve from Redis if available |

### Response `200`

```json
{
  "interestRates": {
    "aave-usdc-1": [
      { "timestamp": "1710000000", "rate": "0.042", "nativeRate": "0.03", "rewardRate": "0.012" }
    ],
    "aave-weth-1": []
  }
}
```

The response is a map from `productId` to an array of up to 20 rate records.

---

## POST `/api/vault/rates`

Returns the most recent rate records plus 24h / 7d / 30d SMAs for one or more FleetCommander vault addresses. See [fleet-commander.md](../contracts/core/reference/contracts/fleet-commander.md) for the on-chain contract.

### Request body

```json
{
  "fleets": [
    { "chainId": "1", "fleetAddress": "0xabc..." },
    { "chainId": "8453", "fleetAddress": "0xdef..." }
  ],
  "first": 1
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `fleets` | array | yes | Each entry must have `chainId` and `fleetAddress` |
| `first` | number | no | Number of latest raw rate records to return per fleet (default `1`) |

### Response `200`

```json
{
  "rates": [
    {
      "chainId": "1",
      "fleetAddress": "0xabc...",
      "sma": {
        "sma24h": "0.043",
        "sma7d": "0.041",
        "sma30d": "0.038"
      },
      "rates": [
        { "id": "...", "rate": "0.045", "timestamp": 1710000000, "fleetAddress": "0xabc..." }
      ]
    }
  ]
}
```

SMAs are computed over `hourlyFleetInterestRate` (24h), `dailyFleetInterestRate` (7d and 30d) tables.

---

## POST `/api/vault/historicalRates`

Returns full daily / hourly / weekly historical rate series for one or more fleet vaults.

### Request body

Same shape as `/api/vault/rates` (`fleets` array; `first` is ignored).

### Response `200`

```json
{
  "rates": [
    {
      "chainId": "1",
      "fleetAddress": "0xabc...",
      "rates": {
        "dailyRates": [ { "id": "...", "averageRate": "0.042", "date": "...", "fleetAddress": "0xabc..." } ],
        "hourlyRates": [ ... ],
        "weeklyRates": [ ... ],
        "latestRate": [ { "id": "...", "rate": "0.045", "timestamp": 1710000000, "fleetAddress": "0xabc..." } ]
      }
    }
  ]
}
```

Limits mirror get-rates: 365 daily, 720 hourly, 156 weekly.

---

## GET `/api/apy/{chainId}/{protocol}`

Computes the net APY for a position on a supported lending protocol. Rates are fetched from the earn-rates subgraph and adjusted for the price appreciation of supplied and borrowed tokens (via DeFi Llama yield data).

### Path parameters

| Parameter | Type | Description |
|---|---|---|
| `chainId` | number | Numeric chain ID |
| `protocol` | string | `ProtocolId` value: `aave-v3` (or alias `aave3`), `aave-v2`, `spark`, `morphoblue`, `ajna`, `maker` |

### Query parameters — Aave / Spark positions

| Parameter | Type | Required | Description |
|---|---|---|---|
| `collateral` | string (address list) | yes | Collateral token address(es), comma-separated |
| `debt` | string (address list) | yes | Debt token address(es), comma-separated |
| `ltv` | number | yes | Target LTV as a decimal (e.g. `0.65`) |
| `referenceDate` | string | yes | ISO date string used as the end date for the 1-year rate window |

### Query parameters — Morpho Blue positions

| Parameter | Type | Required | Description |
|---|---|---|---|
| `marketId` | `0x` + 64-char hex | yes | Morpho Blue market identifier |
| `ltv` | number | yes | Target LTV |
| `mode` | `supply` or `borrow` | yes | Position mode |
| `referenceDate` | string | yes | End date for rate window |

### Query parameters — Ajna positions

| Parameter | Type | Required | Description |
|---|---|---|---|
| `poolAddress` | address | yes | Ajna pool address |
| `ltv` | number | yes | Target LTV |
| `mode` | `supply` or `borrow` | yes | Position mode |
| `referenceDate` | string | yes | End date for rate window |

### Response `200`

```json
{
  "multiply": 1.65,
  "position": { "collateral": ["0x..."], "debt": ["0x..."], "ltv": 0.65, "referenceDate": "2024-03-10" },
  "positionData": {},
  "results": {
    "apy": 0.087,
    "apy365d": 0.087,
    "apy30d": 0.082,
    "apy7d": 0.091
  }
}
```

`multiply` is the leverage multiple derived from `ltv`. `apy` is an alias for `apy365d`. The cache TTL for APY results is 6 hours.
