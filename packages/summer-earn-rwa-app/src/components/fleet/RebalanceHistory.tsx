import { formatDecimalOutput, formatUnixDate } from '@/lib/format'
import type { SubgraphRebalance } from '@/lib/subgraph/types'

interface Props {
  rebalances: SubgraphRebalance[]
}

export function RebalanceHistory({ rebalances }: Props) {
  if (rebalances.length === 0) {
    return <div className="text-sm text-[var(--text-3)]">No rebalances on record.</div>
  }
  return (
    <div className="divide-y divide-[var(--border-faint)]">
      {rebalances.map((rb) => (
        <div key={rb.id} className="flex items-center justify-between gap-4 py-3 text-sm">
          <div>
            <div>
              {(rb.from.name ?? rb.from.id.slice(0, 8))} →{' '}
              {(rb.to.name ?? rb.to.id.slice(0, 8))}
            </div>
            <div className="mt-1 font-mono text-xs text-[var(--text-3)]">
              {formatUnixDate(BigInt(rb.timestamp))}
            </div>
          </div>
          <div className="text-right">
            <div className="font-mono">
              {formatDecimalOutput(BigInt(rb.amount), rb.asset.decimals)} {rb.asset.symbol}
            </div>
            {rb.amountUSD && (
              <div className="mt-1 font-mono text-xs text-[var(--text-3)]">
                ≈ ${Number(rb.amountUSD).toLocaleString('en-US', { maximumFractionDigits: 0 })}
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  )
}
