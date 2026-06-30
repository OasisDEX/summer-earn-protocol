'use client'

import { usePathname, useSearchParams } from 'next/navigation'

import { type ChainId, resolveChainParam } from '@/types/chain'

// Single source of truth for the active chain in client components.
//
// Encoding (mirrors the page routing):
//   - /strategy/<slug>/<id>  → slug is a route segment
//   - everything else        → `?chain=<slug>` query param
// Falls back to the default chain (Base) when absent/invalid.
const STRATEGY_SLUG_RE = /^\/strategy\/(base|mainnet)\//

export function useActiveChain(): ChainId {
  const pathname = usePathname() ?? '/'
  const searchParams = useSearchParams()

  const match = pathname.match(STRATEGY_SLUG_RE)
  const raw = match ? match[1] : searchParams.get('chain') ?? undefined
  return resolveChainParam(raw)
}
