'use cache'

import { cacheLife, cacheTag } from 'next/cache'

import { resolveEnsNames } from './ens'

// ENS reverse records are effectively static, and resolving them on mainnet is the
// slowest part of rendering a proposal (one request per voter). Cache the resolved
// map for a long window; the `ens` tag can be purged via `/api/revalidate` if needed.
// Addresses are sorted so the cache key is independent of voter order.
export async function getEnsNamesCached(addresses: string[]): Promise<Record<string, string>> {
  cacheLife('days')
  cacheTag('ens')
  return resolveEnsNames([...addresses].sort())
}
