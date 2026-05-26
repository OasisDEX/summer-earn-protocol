import { cacheLife, cacheTag } from 'next/cache'
import type { Address } from 'viem'

import 'server-only'

import { gqlFetch } from '@/lib/subgraph/client'
import { STRATEGIES_BY_OWNER_FIRST } from '@/lib/subgraph/queries'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export interface PortfolioInitial {
  owner: Address
  strategies: SubgraphStrategy[]
}

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

export async function loadPortfolio(chainId: ChainId, owner: Address): Promise<PortfolioInitial> {
  const strategies = await fetchCachedStrategiesByOwner(chainId, owner)
  return { owner, strategies }
}
