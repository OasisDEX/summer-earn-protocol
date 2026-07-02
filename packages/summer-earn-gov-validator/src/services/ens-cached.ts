'use cache'

import { cacheLife, cacheTag } from 'next/cache'

import { resolveEnsNamesDynamoCached } from './ens-dynamo'

// ENS reverse records are effectively static, and resolving them on mainnet is the
// slowest part of rendering a proposal (one request per voter). Two cache layers:
// this in-process `use cache` (days) and per-address DynamoDB entries (a week,
// shared across instances — see ens-dynamo.ts). The `ens` tag can be purged via
// `/api/revalidate` if needed.
//
// NOTE: Next's `use cache` keys on the serialized argument, so callers must pass an
// already-normalized (deduped + sorted) address list for the cache key to be
// order-independent — e.g. `getEnsNamesCached([...new Set(addrs)].sort())`.
export async function getEnsNamesCached(addresses: string[]): Promise<Record<string, string>> {
  cacheLife('days')
  cacheTag('ens')
  return resolveEnsNamesDynamoCached(addresses)
}
