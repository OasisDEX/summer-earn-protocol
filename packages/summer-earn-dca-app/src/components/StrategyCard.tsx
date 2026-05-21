'use client'

import Link from 'next/link'
import { type Address,getAddress } from 'viem'

import { MiniChart } from '@/components/charts/MiniChart'
import { StatusBadge } from '@/components/TxStatusBadge'
import { Button } from '@/components/ui/Button'
import { Countdown } from '@/components/ui/Countdown'
import { Pair } from '@/components/ui/Pair'
import { Progress } from '@/components/ui/Progress'
import { useDcaStrategyActions } from '@/hooks/useDcaStrategyActions'
import { useHybridStrategy } from '@/hooks/useHybridStrategy'
import { useStrategyMetadata } from '@/hooks/useTokenMetadata'
import { useTokenPriceHistory } from '@/hooks/useTokenPriceHistory'
import { formatDecimalOutput } from '@/lib/format'
import { toStrategyConfigStruct } from '@/lib/strategy/encode'
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
  const priceHistory = useTokenPriceHistory({
    chainId,
    token: getAddress(strategy.outAsset) as Address,
    feed: getAddress(strategy.outAssetFeed) as Address,
    range: '30d',
  })
  const actions = useDcaStrategyActions({ chainId })

  const status = hybrid.data?.displayStatus ?? strategy.status
  const tradesExecuted = Number(hybrid.data?.displayTradesExecuted ?? strategy.tradesExecuted)
  const nextTriggerAt = hybrid.data?.displayNextTriggerAt ?? BigInt(strategy.nextTriggerAt)
  const maxTrades = Number(strategy.maxTrades)
  const inDec = meta.data?.inAsset.decimals ?? 18
  const outDec = meta.data?.outAsset.decimals ?? 18
  // FleetCommander share decimals usually match the underlying asset — 6 for
  // USDC, 18 for WETH. `tradeAmount` is stored in shares; formatting it with
  // a hardcoded 18 would render a USDC strategy as `0.000000000000…`.
  const shareDec = meta.data?.sourceVault.decimals ?? inDec
  const inSym = meta.data?.inAsset.symbol ?? '…'
  const outSym = meta.data?.outAsset.symbol ?? '…'
  const tuple = hybrid.data ? toStrategyConfigStruct(hybrid.data.subgraph) : undefined

  return (
    <article className="overflow-hidden rounded-lg border border-[var(--border-faint)] bg-[var(--surface)] transition hover:border-[var(--border-strong)]">
      <div className="p-6">
        <div className="flex items-start justify-between gap-3">
          <Pair from={inSym} to={outSym} sub={`#${strategy.strategyId}`} />
          <StatusBadge status={status} />
        </div>

        <dl className="mt-5 grid grid-cols-2 gap-x-6 gap-y-3 text-sm">
          <KV label="Per trade">
            {formatDecimalOutput(BigInt(strategy.tradeAmount), shareDec, 4)} {inSym}
          </KV>
          <KV label="Interval">{Math.round(Number(strategy.interval) / 86_400)}d</KV>
          <KV label="Acquired">
            {formatDecimalOutput(BigInt(strategy.totalOutAssetReceived), outDec, 4)} {outSym}
          </KV>
          <KV label="Spent">
            {formatDecimalOutput(BigInt(strategy.totalInAssetSwapped), inDec, 2)} {inSym}
          </KV>
        </dl>

        <div className="mt-4">
          <Progress value={tradesExecuted} total={maxTrades > 0 ? maxTrades : tradesExecuted || 1} />
        </div>

        <div className="mt-3">
          <MiniChart data={priceHistory.data?.series?.points ?? []} height={56} />
        </div>
      </div>

      <div className="flex items-center justify-between gap-3 border-t border-[var(--border-faint)] bg-[var(--surface-2)] px-6 py-3">
        <div className="font-mono text-xs text-[var(--text-3)]">
          {status === 'ACTIVE' ? (
            <>
              Next in <Countdown targetSec={nextTriggerAt} className="text-[var(--text)]" />
            </>
          ) : status === 'PAUSED' ? (
            'Paused'
          ) : status === 'COMPLETED' ? (
            'Completed'
          ) : (
            'Cancelled'
          )}
        </div>
        <div className="flex items-center gap-2">
          {status === 'ACTIVE' && tuple && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => actions.pauseStrategy(BigInt(strategy.strategyId), tuple)}
              loading={actions.pauseTx.isWriting || actions.pauseTx.isMining}
            >
              Pause
            </Button>
          )}
          {status === 'PAUSED' && tuple && (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => actions.resumeStrategy(BigInt(strategy.strategyId), tuple)}
              loading={actions.resumeTx.isWriting || actions.resumeTx.isMining}
            >
              Resume
            </Button>
          )}
          <Link
            href={`/strategy/${strategy.strategyId}`}
            className="rounded-pill border border-[var(--border)] px-3 py-1 text-xs text-[var(--text-2)] transition hover:border-[var(--border-strong)] hover:text-[var(--text)]"
          >
            Open
          </Link>
        </div>
      </div>
    </article>
  )
}

function KV({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="text-[11px] uppercase tracking-[0.06em] text-[var(--text-3)]">{label}</dt>
      <dd className="mt-1 font-mono text-[13px] text-[var(--text)]">{children}</dd>
    </div>
  )
}
