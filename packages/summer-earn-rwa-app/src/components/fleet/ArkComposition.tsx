import { Progress } from '@/components/ui/Progress'
import { formatDecimalOutput } from '@/lib/format'
import type { ArkInfo } from '@/types/fleet'

interface Props {
  arks: ArkInfo[]
  totalAssets: bigint
  assetDecimals: number
  assetSymbol: string
}

export function ArkComposition({ arks, totalAssets, assetDecimals, assetSymbol }: Props) {
  if (arks.length === 0) {
    return <div className="text-sm text-[var(--text-3)]">No active arks.</div>
  }
  return (
    <div className="divide-y divide-[var(--border-faint)]">
      {arks.map((ark) => {
        const pct = totalAssets > 0n ? Number((ark.totalAssets * 10_000n) / totalAssets) / 100 : 0
        return (
          <div key={ark.address} className="flex items-center justify-between gap-4 py-4">
            <div>
              <div className="text-sm font-medium">
                {ark.isBufferArk ? 'Buffer · ' : ''}
                {ark.name || 'Ark'}
              </div>
              <div className="mt-1 font-mono text-xs text-[var(--text-3)]">{ark.address}</div>
            </div>
            <div className="text-right">
              <div className="font-mono text-sm text-[var(--text)]">
                {formatDecimalOutput(ark.totalAssets, assetDecimals)} {assetSymbol}
              </div>
              <div className="mt-1 font-mono text-xs text-[var(--text-3)]">{pct.toFixed(2)}%</div>
              <div className="mt-1">
                <Progress value={Math.round(pct)} total={100} showLabel={false} />
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}
