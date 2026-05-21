'use client'

import { type Address,getAddress } from 'viem'

import { Sparkline } from '@/components/charts/Sparkline'
import { Stat } from '@/components/ui/Stat'
import { KNOWN_TOKEN_ADDRESSES } from '@/config/addresses'
import { useTokenSparkline } from '@/hooks/useTokenSparkline'
import { formatDecimalOutput } from '@/lib/format'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

interface PortfolioKpisProps {
  chainId: ChainId
  strategies: SubgraphStrategy[]
}

// KPI tile row at the top of the Portfolio dashboard.
// - "Value in DCA" — sum of total-in across active+paused strategies (in
//   inAsset units, formatted at 18d as a stand-in for USDC's 6d display).
// - "Acquired (USD)" — sum of total-out received (approximated; the chart
//   sparkline shows ETH USD as a stand-in until we expose a portfolio aggregate).
// - "Source yield" — placeholder until the vault APY hook is wired.
// - "Next trigger" — the soonest pending execution across active strategies.
export function PortfolioKpis({ chainId, strategies }: PortfolioKpisProps) {
  const eth = getAddress(KNOWN_TOKEN_ADDRESSES[chainId].weth) as Address
  const ethSparkline = useTokenSparkline(chainId, eth)

  const active = strategies.filter((s) => s.status === 'ACTIVE' || s.status === 'PAUSED')

  const totalIn = active.reduce((acc, s) => acc + BigInt(s.totalInAssetSwapped), 0n)
  const totalOut = active.reduce((acc, s) => acc + BigInt(s.totalOutAssetReceived), 0n)
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
        label="Total spent"
        value={formatDecimalOutput(totalIn, 18, 2)}
        sub="lifetime"
      >
        <Sparkline points={ethSparkline.points} />
      </Stat>
      <Stat
        label="Total acquired"
        value={formatDecimalOutput(totalOut, 18, 4)}
        sub="lifetime"
      >
        <Sparkline points={ethSparkline.points} />
      </Stat>
      <Stat
        label="Next trigger"
        value={soonest > 0n ? `${days}d ${hours}h` : '—'}
        sub={soonest > 0n ? 'soonest pending' : 'none scheduled'}
      />
    </div>
  )
}
