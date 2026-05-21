'use client'

import { useMemo, useState } from 'react'

import { LineChart } from '@/components/charts/LineChart'
import { EditStrategyModal } from '@/components/EditStrategyModal'
import { ExecutionHistoryTable } from '@/components/ExecutionHistoryTable'
import { FreshFromChainPill, StatusBadge } from '@/components/TxStatusBadge'
import { Button } from '@/components/ui/Button'
import { Card, CardHeader, CardSub, CardTitle } from '@/components/ui/Card'
import { Pair } from '@/components/ui/Pair'
import { Pill } from '@/components/ui/Pill'
import { Segmented } from '@/components/ui/Segmented'
import { useDcaStrategyActions } from '@/hooks/useDcaStrategyActions'
import { useHybridStrategy } from '@/hooks/useHybridStrategy'
import { useSourceVaultPreview } from '@/hooks/useSourceVaultPreview'
import { type StrategyChartInitialData, useStrategyChartData } from '@/hooks/useStrategyChartData'
import { useStrategyMetadata } from '@/hooks/useTokenMetadata'
import { formatBpsAsPercent, formatDecimalOutput, formatUnixDate } from '@/lib/format'
import type { PriceRange, PriceSeries } from '@/lib/prices'
import type {
  SourceVaultPreview as InitialSourcePreview,
  StrategyMetadata as InitialMetadata,
} from '@/lib/server/loadStrategyDetail'
import { toStrategyConfigStruct } from '@/lib/strategy/encode'
import { formatCountdown } from '@/lib/strategy/intervals'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'
import type { StrategyStateOnchain } from '@/types/strategy'

export interface StrategyDetailInitialProps {
  subgraph: SubgraphStrategy | null
  inSeries: PriceSeries | null
  outSeries: PriceSeries | null
  range: PriceRange
  metadata: InitialMetadata | null
  sourcePreview: InitialSourcePreview | null
  rpcState: StrategyStateOnchain | null
}

const RANGES: Array<{ value: PriceRange; label: string }> = [
  { value: '7d', label: '7d' },
  { value: '30d', label: '30d' },
  { value: '90d', label: '90d' },
  { value: 'all', label: 'All' },
]

export function StrategyDetail({
  chainId,
  strategyId,
  initial,
}: {
  chainId: ChainId
  strategyId: string
  initial?: StrategyDetailInitialProps
}) {
  const [range, setRange] = useState<PriceRange>(initial?.range ?? '90d')
  const hybrid = useHybridStrategy(chainId, strategyId, initial?.subgraph, initial?.rpcState)
  const meta = useStrategyMetadata({
    chainId,
    inAsset: hybrid.data?.subgraph.inAsset,
    outAsset: hybrid.data?.subgraph.outAsset,
    sourceVault: hybrid.data?.subgraph.sourceVault,
    targetVault: hybrid.data?.subgraph.targetVault,
    inAssetFeed: hybrid.data?.subgraph.inAssetFeed,
    outAssetFeed: hybrid.data?.subgraph.outAssetFeed,
    initialData: initial?.metadata,
  })
  const chartInitial = useMemo<StrategyChartInitialData | undefined>(
    () =>
      initial
        ? {
            subgraph: initial.subgraph,
            inSeries: initial.inSeries,
            outSeries: initial.outSeries,
            range: initial.range,
          }
        : undefined,
    [initial],
  )
  const chart = useStrategyChartData(chainId, strategyId, range, chartInitial)
  const actions = useDcaStrategyActions({ chainId })
  const sourcePreview = useSourceVaultPreview({
    chainId,
    sourceVault: hybrid.data?.subgraph.sourceVault as `0x${string}` | undefined,
    shares: hybrid.data ? BigInt(hybrid.data.subgraph.tradeAmount) : undefined,
    initialData: initial?.sourcePreview,
  })

  const tuple = useMemo(
    () => (hybrid.data ? toStrategyConfigStruct(hybrid.data.subgraph) : undefined),
    [hybrid.data],
  )

  // Local-only drag preview; saved through the Edit modal.
  const [ceiling, setCeiling] = useState<number | undefined>(undefined)
  const [floor, setFloor] = useState<number | undefined>(undefined)
  const [editOpen, setEditOpen] = useState(false)
  const effectiveCeiling = ceiling ?? chart.data?.ceiling
  const effectiveFloor = floor ?? chart.data?.floor

  const formatRatio = useMemo(() => {
    return (v: number) => {
      if (!Number.isFinite(v)) return '—'
      const abs = Math.abs(v)
      const body =
        abs < 1 ? v.toFixed(4) : abs < 100 ? v.toFixed(2) : Math.round(v).toLocaleString('en-US')
      return `${body} ${meta.data?.inAsset.symbol ?? ''}`.trim()
    }
  }, [meta.data?.inAsset.symbol])

  if (hybrid.isLoading) {
    return (
      <div className="page">
        <div className="skel h-[420px] rounded-lg" />
      </div>
    )
  }
  if (hybrid.isError || !hybrid.data) {
    return (
      <div className="page">
        <Card>
          <CardHeader>
            <CardTitle>Could not load strategy</CardTitle>
          </CardHeader>
          <p className="text-sm text-[var(--text-3)]">
            The subgraph is unreachable. Try again in a moment.
          </p>
        </Card>
      </div>
    )
  }

  const s = hybrid.data.subgraph
  const inSym = meta.data?.inAsset.symbol ?? '…'
  const outSym = meta.data?.outAsset.symbol ?? '…'
  const inDec = meta.data?.inAsset.decimals ?? 18
  const outDec = meta.data?.outAsset.decimals ?? 18
  const shareDec = meta.data?.sourceVault.decimals ?? inDec
  const shareSym = meta.data?.sourceVault.symbol ?? `${inSym}-shares`
  const showStaleness =
    hybrid.data.staleness.statusMismatch || hybrid.data.staleness.tradesDelta !== 0n

  return (
    <div className="page">
      {/* Header strip */}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Pair from={inSym} to={outSym} sub={`#${s.strategyId}`} />
          <StatusBadge status={hybrid.data.displayStatus} />
          {showStaleness && <FreshFromChainPill />}
          {chart.data?.basis === 'off-chain-aggregate' && (
            <Pill variant="neutral" dot={false}>
              off-chain pricing
            </Pill>
          )}
          {chart.data?.basis === 'mixed' && (
            <Pill variant="neutral" dot={false}>
              mixed pricing
            </Pill>
          )}
        </div>
        <div className="flex gap-2">
          {hybrid.data.displayStatus === 'ACTIVE' && tuple && (
            <Button
              variant="secondary"
              onClick={() => actions.pauseStrategy(BigInt(s.strategyId), tuple)}
              loading={actions.pauseTx.isWriting || actions.pauseTx.isMining}
            >
              Pause
            </Button>
          )}
          {hybrid.data.displayStatus === 'PAUSED' && tuple && (
            <Button
              variant="secondary"
              onClick={() => actions.resumeStrategy(BigInt(s.strategyId), tuple)}
              loading={actions.resumeTx.isWriting || actions.resumeTx.isMining}
            >
              Resume
            </Button>
          )}
          {hybrid.data.displayStatus !== 'CANCELLED' &&
            hybrid.data.displayStatus !== 'COMPLETED' &&
            tuple && (
              <Button variant="secondary" onClick={() => setEditOpen(true)}>
                Edit
              </Button>
            )}
          {hybrid.data.displayStatus !== 'CANCELLED' && tuple && (
            <Button
              variant="danger"
              onClick={() => actions.cancelStrategy(BigInt(s.strategyId), tuple)}
              loading={actions.cancelTx.isWriting || actions.cancelTx.isMining}
            >
              Cancel
            </Button>
          )}
        </div>
      </div>

      {tuple && (
        <EditStrategyModal
          open={editOpen}
          onClose={() => setEditOpen(false)}
          chainId={chainId}
          strategyId={BigInt(s.strategyId)}
          oldConfig={tuple}
          inSym={inSym}
          outSym={outSym}
          shareSym={shareSym}
          inDecimals={inDec}
          shareDecimals={shareDec}
        />
      )}

      {/* Key facts row */}
      <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-5">
        <KV label="Source">{inSym}</KV>
        <KV label="Target">{outSym}</KV>
        <KV label="Interval">{Math.round(Number(s.interval) / 86_400)}d</KV>
        <KV label="Per trade">
          {sourcePreview.data?.assetsFromShares !== undefined
            ? `${formatDecimalOutput(sourcePreview.data.assetsFromShares, inDec, 4)} ${inSym}`
            : `${formatDecimalOutput(BigInt(s.tradeAmount), shareDec, 4)} ${inSym}`}
          <span className="ml-1 text-[var(--text-3)]">
            ({formatDecimalOutput(BigInt(s.tradeAmount), shareDec, 4)} {shareSym})
          </span>
        </KV>
        <KV label="Next trigger">
          {hybrid.data.displayStatus === 'ACTIVE'
            ? formatCountdown(hybrid.data.displayNextTriggerAt)
            : '—'}
        </KV>
      </div>

      {/* Chart card */}
      <Card>
        <CardHeader>
          <div>
            <CardTitle>
              {outSym} price <span className="text-[var(--text-3)]">/ {inSym}</span>
            </CardTitle>
            <CardSub>
              {chart.data?.basis === 'chainlink-feed'
                ? 'Chainlink feed prices — same source as the keeper.'
                : chart.data?.basis === 'off-chain-aggregate'
                  ? 'Off-chain prices — guardrails are evaluated against Chainlink.'
                  : chart.data?.basis === 'mixed'
                    ? 'Filled gaps using off-chain pricing.'
                    : '—'}
            </CardSub>
          </div>
          <Segmented value={range} onChange={setRange} options={RANGES} />
        </CardHeader>
        {chart.isLoading ? (
          <div className="skel w-full rounded-md mt-4" style={{ height: 280 }} />
        ) : (
          <LineChart
            prices={chart.data?.prices ?? []}
            gaps={chart.data?.gaps}
            executions={chart.data?.executions}
            ceiling={effectiveCeiling}
            floor={effectiveFloor}
            onCeilingChange={(v) => setCeiling(v)}
            onFloorChange={(v) => setFloor(v)}
            dataStartsAt={chart.data?.dataStartsAt}
            formatValue={formatRatio}
          />
        )}
        {(ceiling !== undefined || floor !== undefined) && (
          <div className="mt-3 flex items-center justify-end gap-2 text-xs text-[var(--text-3)]">
            <span>Preview — not saved.</span>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setCeiling(undefined)
                setFloor(undefined)
              }}
            >
              Reset
            </Button>
          </div>
        )}
      </Card>

      {/* Stats grid */}
      <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-4">
        <KV label="Total spent">
          {formatDecimalOutput(BigInt(s.totalInAssetSwapped), inDec, 2)} {inSym}
        </KV>
        <KV label="Total acquired">
          {formatDecimalOutput(BigInt(s.totalOutAssetReceived), outDec, 4)} {outSym}
        </KV>
        <KV label="Slippage tolerance">{formatBpsAsPercent(BigInt(s.slippageBps))}</KV>
        <KV label="End date">
          {BigInt(s.endDate) === 0n ? '—' : formatUnixDate(BigInt(s.endDate))}
        </KV>
      </div>

      {/* Executions */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Executions</CardTitle>
          <CardSub>
            {hybrid.data.displayTradesExecuted.toString()} of {s.maxTrades}
          </CardSub>
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

function KV({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="text-[11px] uppercase tracking-[0.06em] text-[var(--text-3)]">{label}</div>
      <div className="mt-1 font-mono text-sm text-[var(--text)]">{children}</div>
    </div>
  )
}
