'use client'

import { Stat } from '@/components/ui/Stat'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

interface PortfolioKpisProps {
  chainId: ChainId
  strategies: SubgraphStrategy[]
}

// TODO(usd-aggregates): a "Total spent" / "Total acquired" tile needs to
// convert each strategy's `totalInAssetSwapped` / `totalOutAssetReceived`
// to USD via `useTokenPriceHistory({ token: inAsset, range: 'all' })` —
// pick the nearest price at each execution timestamp, sum across all
// strategies, display in dollars. Summing the raw BigInt values across
// mixed-decimal assets (USDC=6, WETH=18) is meaningless, so we don't
// surface a "Total" tile at all until that conversion lands.
//
// Kept tiles: strategy count + soonest next trigger. Both are unit-free.
export function PortfolioKpis({ strategies }: PortfolioKpisProps) {
  const active = strategies.filter((s) => s.status === 'ACTIVE' || s.status === 'PAUSED')
  const paused = strategies.filter((s) => s.status === 'PAUSED').length
  const completed = strategies.filter((s) => s.status === 'COMPLETED').length

  const nextTriggers = active
    .filter((s) => s.status === 'ACTIVE')
    .map((s) => BigInt(s.nextTriggerAt))
    .filter((n) => n > 0n)
  const soonest = nextTriggers.length > 0 ? nextTriggers.sort((a, b) => Number(a - b))[0] : 0n
  const secsUntil = soonest > 0n ? Number(soonest) - Math.floor(Date.now() / 1000) : 0
  const days = Math.max(0, Math.floor(secsUntil / 86_400))
  const hours = Math.max(0, Math.floor((secsUntil % 86_400) / 3600))

  return (
    <div className="grid grid-cols-1 gap-3.5 md:grid-cols-2 lg:grid-cols-4">
      <Stat
        label="Strategies"
        value={strategies.length.toString()}
        sub={`${active.length} active`}
      />
      <Stat
        label="Active"
        value={(active.length - paused).toString()}
        sub={paused > 0 ? `+ ${paused} paused` : 'live now'}
      />
      <Stat
        label="Completed"
        value={completed.toString()}
        sub={completed > 0 ? 'lifetime' : 'none yet'}
      />
      <Stat
        label="Next trigger"
        value={soonest > 0n ? `${days}d ${hours}h` : '—'}
        sub={soonest > 0n ? 'soonest pending' : 'none scheduled'}
      />
    </div>
  )
}
