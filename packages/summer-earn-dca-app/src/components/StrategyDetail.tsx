'use client'

import { useMemo } from 'react'

import { ExecutionHistoryTable } from '@/components/ExecutionHistoryTable'
import { FeedPriceDisplay } from '@/components/FeedPriceDisplay'
import { FreshFromChainPill, StatusBadge } from '@/components/TxStatusBadge'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardTitle } from '@/components/ui/Card'
import { useDcaStrategyActions } from '@/hooks/useDcaStrategyActions'
import { useHybridStrategy } from '@/hooks/useHybridStrategy'
import { useStrategyMetadata } from '@/hooks/useTokenMetadata'
import {
  formatBpsAsPercent,
  formatDecimalOutput,
  formatFeedPrice,
  formatUnixDate,
} from '@/lib/format'
import { toStrategyConfigStruct } from '@/lib/strategy/encode'
import { formatCountdown } from '@/lib/strategy/intervals'
import type { ChainId } from '@/types/chain'

export function StrategyDetail({
  chainId,
  strategyId,
}: {
  chainId: ChainId
  strategyId: string
}) {
  const { data: hybrid, isLoading, isError } = useHybridStrategy(chainId, strategyId)
  const meta = useStrategyMetadata({
    chainId,
    inAsset: hybrid?.subgraph.inAsset,
    outAsset: hybrid?.subgraph.outAsset,
    sourceVault: hybrid?.subgraph.sourceVault,
    targetVault: hybrid?.subgraph.targetVault,
    inAssetFeed: hybrid?.subgraph.inAssetFeed,
    outAssetFeed: hybrid?.subgraph.outAssetFeed,
  })

  const actions = useDcaStrategyActions({ chainId })

  const tuple = useMemo(
    () => (hybrid ? toStrategyConfigStruct(hybrid.subgraph) : undefined),
    [hybrid],
  )

  if (isLoading) return <div className="text-surface-300">Loading…</div>
  if (isError || !hybrid)
    return (
      <div className="rounded-lg border border-danger/40 bg-danger/10 p-4 text-sm text-danger">
        Could not load strategy.
      </div>
    )

  const s = hybrid.subgraph
  const inSym = meta.data?.inAsset.symbol ?? '…'
  const outSym = meta.data?.outAsset.symbol ?? '…'
  const inDec = meta.data?.inAsset.decimals ?? 18
  const outDec = meta.data?.outAsset.decimals ?? 18
  const shareDec = meta.data?.sourceVault.decimals ?? 18
  const inFeedDec = meta.data?.inAssetFeed.decimals ?? 8

  const showStaleness =
    hybrid.staleness.statusMismatch || hybrid.staleness.tradesDelta !== 0n

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <div className="flex flex-wrap items-center gap-2">
            <CardTitle>
              {inSym} → {outSym}
            </CardTitle>
            <StatusBadge status={hybrid.displayStatus} />
            {showStaleness && <FreshFromChainPill />}
            <span className="ml-2 hidden text-xs text-surface-400 md:inline">
              In:&nbsp;
              <FeedPriceDisplay
                chainId={chainId}
                feed={s.inAssetFeed}
                symbol={inSym}
                compact
              />
              <span className="mx-2 text-surface-700">|</span>
              Out:&nbsp;
              <FeedPriceDisplay
                chainId={chainId}
                feed={s.outAssetFeed}
                symbol={outSym}
                compact
              />
            </span>
          </div>
          <div className="flex gap-2">
            {hybrid.displayStatus === 'ACTIVE' && (
              <Button
                variant="secondary"
                onClick={() => actions.pauseStrategy(BigInt(s.strategyId))}
                loading={actions.pauseTx.isWriting || actions.pauseTx.isMining}
              >
                Pause
              </Button>
            )}
            {hybrid.displayStatus === 'PAUSED' && tuple && (
              <Button
                variant="secondary"
                onClick={() => actions.resumeStrategy(tuple)}
                loading={actions.resumeTx.isWriting || actions.resumeTx.isMining}
              >
                Resume
              </Button>
            )}
            {hybrid.displayStatus !== 'CANCELLED' && (
              <Button
                variant="danger"
                onClick={() => actions.cancelStrategy(BigInt(s.strategyId))}
                loading={actions.cancelTx.isWriting || actions.cancelTx.isMining}
              >
                Cancel
              </Button>
            )}
          </div>
        </CardHeader>

        <dl className="grid grid-cols-2 gap-4 text-sm md:grid-cols-4">
          <Stat label="Strategy id">#{s.strategyId}</Stat>
          <Stat label="Owner">{s.owner.id}</Stat>
          <Stat label="Trade amount (shares)">
            {formatDecimalOutput(BigInt(s.tradeAmount), shareDec)}
          </Stat>
          <Stat label="Interval">{Number(s.interval) / 86_400}d</Stat>
          <Stat label="Slippage">{formatBpsAsPercent(BigInt(s.slippageBps))}</Stat>
          <Stat label="Trades">
            {hybrid.displayTradesExecuted.toString()} / {s.maxTrades}
          </Stat>
          <Stat label="Next trigger">
            {hybrid.displayStatus === 'ACTIVE'
              ? formatCountdown(hybrid.displayNextTriggerAt)
              : '—'}
          </Stat>
          <Stat label="End date">
            {BigInt(s.endDate) === 0n ? '—' : formatUnixDate(BigInt(s.endDate))}
          </Stat>
          <Stat label="Max price (ceiling)">
            {BigInt(s.maxPrice) === 0n
              ? '—'
              : `$${formatFeedPrice(BigInt(s.maxPrice), inFeedDec)}`}
          </Stat>
          <Stat label="Min price (floor)">
            {BigInt(s.minPrice) === 0n
              ? '—'
              : `$${formatFeedPrice(BigInt(s.minPrice), inFeedDec)}`}
          </Stat>
          <Stat label="Live in-asset price">
            <FeedPriceDisplay chainId={chainId} feed={s.inAssetFeed} symbol={inSym} />
          </Stat>
          <Stat label="Live out-asset price">
            <FeedPriceDisplay chainId={chainId} feed={s.outAssetFeed} symbol={outSym} />
          </Stat>
          <Stat label="Total in">
            {formatDecimalOutput(BigInt(s.totalInAssetSwapped), inDec)} {inSym}
          </Stat>
          <Stat label="Total out">
            {formatDecimalOutput(BigInt(s.totalOutAssetReceived), outDec)} {outSym}
          </Stat>
        </dl>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Execution history</CardTitle>
        </CardHeader>
        <ExecutionHistoryTable
          chainId={chainId}
          executions={s.executions ?? []}
          inDecimals={inDec}
          outDecimals={outDec}
          inSymbol={inSym}
          outSymbol={outSym}
        />
      </Card>
    </div>
  )
}

function Stat({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="text-[11px] uppercase tracking-wide text-surface-500">{label}</dt>
      <dd className="break-all text-surface-100">{children}</dd>
    </div>
  )
}
