import { cacheLife, cacheTag } from 'next/cache'
import type { Address } from 'viem'

import 'server-only'

import { gqlFetch } from '@/lib/subgraph/client'
import { STRATEGIES_BY_OWNER_FIRST } from '@/lib/subgraph/queries'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export interface PortfolioInitial {
  /** Owner echoed back (lowercased) — lets the client check that the
   *  initialData matches the address it's about to query for. */
  owner: Address
  strategies: SubgraphStrategy[]
}

// Cached subgraph read keyed by (chainId, owner). 30s revalidate matches
// the client-side `staleTime` so a hydrated client doesn't immediately
// refetch what the server just delivered.
async function fetchCachedStrategiesByOwner(
  chainId: ChainId,
  owner: Address,
): Promise<SubgraphStrategy[]> {
  'use cache'
  cacheLife({ stale: 30, revalidate: 60, expire: 3600 })
  cacheTag('portfolio', `portfolio:${chainId}:${owner.toLowerCase()}`)
  const data = await gqlFetch<{ strategies: SubgraphStrategy[] }>(
    chainId,
    STRATEGIES_BY_OWNER_FIRST,
    { owner: owner.toLowerCase(), first: 50 },
  )
  return data.strategies
}

// Server-side loader for `/portfolio/[address]`. Mirrors the detail-page pattern:
// pulls the full strategies-by-owner page so the client subtree paints
// with the list already in hand. Per-card fan-out (metadata, sparkline,
// vault preview) still happens client-side after hydration.
export async function loadPortfolio(
  chainId: ChainId,
  owner: Address,
): Promise<PortfolioInitial> {
  const strategies = await fetchCachedStrategiesByOwner(chainId, owner)
  return { owner, strategies }
}
