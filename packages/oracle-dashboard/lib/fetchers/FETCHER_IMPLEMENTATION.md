# Offchain Fetcher Implementation Guide

This document explains how to implement a new offchain data fetcher for the Oracle Dashboard and CLI.

## Overview

Offchain fetchers fetch price/NAV data from external APIs (e.g. WisdomTree, other fund providers). Each fetcher is keyed by **type** and **subtype**:

- **type**: Oracle provider (e.g. `WisdomTree`)
- **subtype**: Data source variant (e.g. `variableNav`, `fixedNav`)

## Interface

Every fetcher must implement:

```typescript
(identifier: string) => Promise<OracleData>
```

Where `OracleData` is:

```typescript
interface OracleData {
  ticker: string    // Asset identifier (e.g. "SPXUX")
  nav: number       // Price/NAV value (e.g. 8.7423)
  dt: string        // Date string YYYY-MM-DD
  timestamp: number // Unix timestamp (seconds)
}
```

The `identifier` is typically the ticker symbol (e.g. `"WTTSX"`).

## Implementation Steps

### 1. Add schema enums (if new type/subtype)

In `packages/oracle-dashboard/lib/schemas.ts` and `packages/oracle-cli/src/schemas.ts`:

```typescript
export const OracleTypeSchema = z.enum(['WisdomTree', 'NewProvider'])
export const OracleSubtypeSchema = z.enum(['variableNav', 'fixedNav', 'newSubtype'])
```

### 2. Create the fetcher file

Create `packages/oracle-dashboard/lib/fetchers/{type}-{subtype}.ts` (lowercase, hyphenated).

Example: `newprovider-fixnav.ts`

```typescript
export interface OracleData {
  ticker: string
  nav: number
  dt: string
  timestamp: number
}

export async function fetchOracleData(identifier: string): Promise<OracleData> {
  const url = `https://api.example.com/nav/${identifier}`
  const response = await fetch(url, { signal: AbortSignal.timeout(10000) })
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  const data = await response.json()
  return {
    ticker: data.symbol ?? identifier,
    nav: data.price,
    dt: data.date,
    timestamp: Math.floor(new Date(data.date).getTime() / 1000),
  }
}
```

### 3. Register in the fetcher factory

In `packages/oracle-dashboard/lib/fetchers/index.ts`:

```typescript
import { fetchOracleData as fetchNewProviderFixNav } from './newprovider-fixnav'

export function getOffchainFetcher(type: OracleType, subtype: OracleSubtype): OffchainFetcher | null {
  // ...existing cases...
  if (type === 'NewProvider' && subtype === 'fixNav') {
    return fetchNewProviderFixNav
  }
  return null
}
```

### 4. Mirror in oracle-cli (if needed)

If the CLI `update` or `start` commands should support this oracle type:

1. Create `packages/oracle-cli/src/fetchers/{type}-{subtype}.ts` (same logic as dashboard)
2. Update `packages/oracle-cli/src/fetchers/index.ts` with the new case
3. When the CLI needs type/subtype per ticker, look up the oracle in `deployments.json` and use `getOffchainFetcher(entry.type, entry.subtype)`.

## Error Handling

- Use retries with exponential backoff for transient failures
- Throw descriptive errors; the dashboard uses `Promise.allSettled` so one failure does not block others
- Log warnings for debugging: `console.warn('[YourFetcher] ...')`

## Response Shape

The external API response must be mapped to `OracleData`. Validate that `nav` and `dt` exist before returning. Use `identifier` as fallback for `ticker` if the API omits it.
