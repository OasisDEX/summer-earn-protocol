---
description: Lambda functions that read and configure on-chain automation triggers (stop-loss, trailing stop-loss, auto-buy, auto-sell, partial take-profit) for Aave, Spark, and Morpho Blue positions.
---

# Triggers

Two Lambda functions handle automation triggers:

- **get-triggers-function** — queries the automation subgraph and returns all active triggers for a proxy or smart-account address, enriched with on-chain details where needed.
- **setup-trigger-function** — validates trigger parameters, simulates the position, and returns an unsigned transaction that registers or updates a trigger.

> **TODO (human input):** Confirm the API Gateway base URL and any required authentication headers.

---

## GET get-triggers

Returns all triggers currently registered on the automation subgraph for a given account address, with full trigger details when requested.

### Query parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `account` | address | yes | Smart-account or proxy address owning the triggers. The deprecated `dpm` alias is also accepted for backwards compatibility. |
| `chainId` | number | yes | Numeric chain ID |
| `poolId` | string | no | Optional pool identifier to narrow results |
| `protocol` | string | no | Optional protocol filter |
| `getDetails` | boolean | no | When `true`, fetch additional on-chain data for each trigger (default `false`) |
| `rpc` | URL | no | Optional custom RPC endpoint |

### Response `200`

```json
{
  "triggers": {
    "aaveStopLoss": { ... },
    "aaveTrailingStopLoss": { ... },
    "aaveAutoBuy": { ... },
    "aaveAutoSell": { ... },
    "aavePartialTakeProfit": { ... },
    "sparkStopLoss": { ... },
    "sparkTrailingStopLoss": { ... },
    "sparkAutoBuy": { ... },
    "sparkAutoSell": { ... },
    "sparkPartialTakeProfit": { ... },
    "morphoBlueStopLoss": { ... },
    "morphoBlueTrailingStopLoss": { ... },
    "morphoBlueAutoBuy": { ... },
    "morphoBlueAutoSell": { ... },
    "morphoBluePartialTakeProfit": { ... }
  },
  "flags": { ... },
  "triggerGroup": { ... },
  "additionalData": { ... }
}
```

The exact shape of each trigger object is determined by the trigger type (simple triggers are built from the subgraph response; advanced triggers require additional RPC or subgraph calls). Absent triggers have `null` or empty values in their fields.

### Response `400`

```json
{
  "message": "Validation Errors",
  "errors": [{ "message": "...", "code": "...", "path": [] }]
}
```

---

## POST setup-trigger

Validates a trigger configuration, simulates the resulting position, and returns the transaction data needed to register or update the trigger on-chain.

### Path parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `chainId` | number | yes | Numeric chain ID |
| `protocol` | string | yes | Protocol identifier — `aave-v3` (or the legacy alias `aave3`), `spark`, `morphoblue` |
| `trigger` | string | yes | Trigger type (see supported values below) |

### Supported trigger values

The `trigger` path segment is one of the `SupportedTriggers` values (hyphenated, lowercase):

| Protocol | Supported triggers |
|---|---|
| `aave-v3` / `aave3` | `auto-buy`, `auto-sell`, `dma-stop-loss`, `dma-trailing-stop-loss`, `dma-partial-take-profit` |
| `spark` (mainnet only) | `auto-buy`, `auto-sell`, `dma-stop-loss`, `dma-trailing-stop-loss`, `dma-partial-take-profit` |
| `morphoblue` (mainnet only) | `auto-buy`, `auto-sell`, `dma-stop-loss`, `dma-trailing-stop-loss`, `dma-partial-take-profit` |

### Request body

The body is a **nested** object whose `triggerData` shape depends on the
`{protocol}/{trigger}` combination. All combinations share the same envelope:

| Field | Type | Description |
|---|---|---|
| `dpm` | address | The user's DPM (proxy / smart-account) address |
| `triggerData` | object | Trigger-specific parameters (varies per trigger; see below) |
| `position` | object | Position addresses `{ collateral, debt }` |
| `rpc` | string (optional) | Optional custom RPC URL |
| `action` | string | One of the `SupportedTriggers` values (e.g. `auto-buy`) |

**Auto-buy (Aave) example** — `triggerData` for `auto-buy` uses LTVs scaled to
basis points (`executionLTV`/`targetLTV`), not decimals:

```json
{
  "dpm": "0x...",
  "triggerData": {
    "executionLTV": "5500",
    "targetLTV": "6000",
    "maxBuyPrice": "3500000000",
    "useMaxBuyPrice": true,
    "maxBaseFee": "300"
  },
  "position": {
    "collateral": "0x...",
    "debt": "0x..."
  },
  "rpc": "https://...",
  "action": "auto-buy"
}
```

> Other triggers (auto-sell, stop-loss, trailing stop-loss, partial take-profit)
> keep the same envelope but a different `triggerData` shape. The authoritative
> per-trigger Zod schemas live in `setup-trigger-function/src/types/validators/`
> — refer to them for exact field-level rules.

### Request headers

| Header | Value | Effect |
|---|---|---|
| `x-summer-skip-validation` | `1` | Skips business-logic validation (e.g. LTV ordering checks). Trigger data is still schema-validated. |

### Response `200`

```json
{
  "simulation": { ... },
  "transaction": {
    "to": "0x...",
    "data": "0x...",
    "value": "0"
  },
  "encodedTriggerData": "0x...",
  "warnings": [
    { "message": "Auto-buy would trigger immediately", "code": "auto-buy-triggered-immediately", "path": [] }
  ]
}
```

`transaction` is an unsigned transaction object ready to be signed and broadcast by the client. `warnings` is a list of non-fatal validation issues. `simulation` contains position state after the hypothetical trigger execution.

### Response `400` — validation errors

```json
{
  "message": "Validation Errors",
  "errors": [
    { "message": "...", "code": "too-low-ltv-to-setup-auto-buy", "path": ["triggerData", "executionLTV"] }
  ],
  "warnings": []
}
```

### Validation error codes (selected)

| Code | Meaning |
|---|---|
| `trigger-already-exists` | Trigger of this type already registered for this account |
| `trigger-does-not-exist` | Attempting to update a trigger that is not yet registered |
| `too-low-ltv-to-setup-auto-buy` | Position LTV is too low to configure auto-buy |
| `auto-buy-triggered-immediately` | (warning) Trigger conditions are already met |
| `stop-loss-triggered-by-auto-buy` | Auto-buy trigger LTV is below the stop-loss |
| `cant-obtain-latest-price` | On-chain price read failed for trailing stop-loss |
