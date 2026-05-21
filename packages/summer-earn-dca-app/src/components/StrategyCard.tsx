'use client'

import Link from 'next/link'

import { StatusBadge } from '@/components/TxStatusBadge'
import { Button } from '@/components/ui/Button'
import { Card } from '@/components/ui/Card'
import { useDcaStrategyActions } from '@/hooks/useDcaStrategyActions'
import { useHybridStrategy } from '@/hooks/useHybridStrategy'
import { useStrategyMetadata } from '@/hooks/useTokenMetadata'
import { formatBpsAsPercent, formatDecimalOutput, formatUnixDate } from '@/lib/format'
import { toStrategyConfigStruct } from '@/lib/strategy/encode'
import { formatCountdown } from '@/lib/strategy/intervals'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export function StrategyCard({
  chainId,
  strategy,
}: {
  chainId: ChainId
  strategy: SubgraphStrategy
}) {
  const hybrid = useHybridStrategy(chainId, strategy.id)
  const meta = useStrategyMetadata({
    chainId,
    inAsset: strategy.inAsset,
    outAsset: strategy.outAsset,
    sourceVault: strategy.sourceVault,
    targetVault: strategy.targetVault,
    inAssetFeed: strategy.inAssetFeed,
    outAssetFeed: strategy.outAssetFeed,
  })

  const actions = useDcaStrategyActions({ chainId })

  const status = hybrid.data?.displayStatus ?? strategy.status
  const tradesExecuted = hybrid.data?.displayTradesExecuted ?? BigInt(strategy.tradesExecuted)
  const nextTriggerAt = hybrid.data?.displayNextTriggerAt ?? BigInt(strategy.nextTriggerAt)
  const totalIn = BigInt(strategy.totalInAssetSwapped)
  const totalOut = BigInt(strategy.totalOutAssetReceived)
  const maxTrades = BigInt(strategy.maxTrades)

  const inDec = meta.data?.inAsset.decimals ?? 18
  const outDec = meta.data?.outAsset.decimals ?? 18
  const inSym = meta.data?.inAsset.symbol ?? '…'
  const outSym = meta.data?.outAsset.symbol ?? '…'

  return (
    <Card>
      <div className="flex items-start justify-between gap-3">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <span className="font-headline text-base font-semibold text-surface-50">
              {inSym} → {outSym}
            </span>
            <StatusBadge status={status} />
          </div>
          <div className="text-xs text-surface-400">Strategy #{strategy.strategyId}</div>
        </div>
        <Link
          href={`/strategy/${strategy.strategyId}`}
          className="rounded-md border border-surface-700 px-2 py-1 text-xs text-surface-200 hover:bg-surface-700/40"
        >
          Open
        </Link>
      </div>

      <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
        <Stat label="Trades">
          {tradesExecuted.toString()}
          {maxTrades > 0n ? ` / ${maxTrades.toString()}` : ''}
        </Stat>
        <Stat label="Next trigger">
          {status === 'ACTIVE' ? formatCountdown(nextTriggerAt) : '—'}
        </Stat>
        <Stat label="Total in">
          {formatDecimalOutput(totalIn, inDec)} {inSym}
        </Stat>
        <Stat label="Total out">
          {formatDecimalOutput(totalOut, outDec)} {outSym}
        </Stat>
        <Stat label="Slippage">{formatBpsAsPercent(BigInt(strategy.slippageBps))}</Stat>
        <Stat label="Ends">
          {BigInt(strategy.endDate) === 0n ? '—' : formatUnixDate(BigInt(strategy.endDate))}
        </Stat>
      </dl>

      <div className="mt-4 flex flex-wrap gap-2">
        {status === 'ACTIVE' && (
          <Button
            variant="secondary"
            onClick={() =>
              actions.pauseStrategy(
                BigInt(strategy.strategyId),
                toStrategyConfigStruct(strategy),
              )
            }
            loading={actions.pauseTx.isWriting || actions.pauseTx.isMining}
          >
            Pause
          </Button>
        )}
        {status === 'PAUSED' && (
          <Button
            variant="secondary"
            onClick={() =>
              actions.resumeStrategy(BigInt(strategy.strategyId), toStrategyConfigStruct(strategy))
            }
            loading={actions.resumeTx.isWriting || actions.resumeTx.isMining}
          >
            Resume
          </Button>
        )}
        {status !== 'CANCELLED' && (
          <Button
            variant="danger"
            onClick={() =>
              actions.cancelStrategy(
                BigInt(strategy.strategyId),
                toStrategyConfigStruct(strategy),
              )
            }
            loading={actions.cancelTx.isWriting || actions.cancelTx.isMining}
          >
            Cancel
          </Button>
        )}
      </div>
    </Card>
  )
}

function Stat({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="text-[11px] uppercase tracking-wide text-surface-500">{label}</dt>
      <dd className="text-surface-100">{children}</dd>
    </div>
  )
}
