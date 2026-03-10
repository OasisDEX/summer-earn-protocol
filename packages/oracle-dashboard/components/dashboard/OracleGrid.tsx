import { useMemo, memo, useState, useEffect } from 'react'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { formatDistanceToNow } from 'date-fns'
import { TickerStats } from '../../hooks/useOracleData'
import { MiniChart } from './MiniChart'

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

interface OracleGridProps {
  stats: TickerStats[]
  searchQuery: string
  onSearchChange: (query: string) => void
  onSelectOracle: (ticker: string) => void
  selectedForBatch: string[]
  onToggleBatchSelection: (ticker: string) => void
  isSelectionMode: boolean
}

// Sub-component to handle the live timer for each grid item without re-rendering the whole grid
const TimeAgo = ({ timestamp }: { timestamp: number }) => {
  const [timeAgoFormatted, setTimeAgoFormatted] = useState<string>('N/A')

  useEffect(() => {
    const update = () => {
      if (timestamp > 0) {
        setTimeAgoFormatted(formatDistanceToNow(timestamp * 1000, { addSuffix: true }))
      } else {
        setTimeAgoFormatted('N/A')
      }
    }
    update()
    const interval = setInterval(update, 1000)
    return () => clearInterval(interval)
  }, [timestamp])

  return <>{timeAgoFormatted}</>
}

export const OracleGrid = memo(function OracleGrid({
  stats,
  searchQuery,
  onSearchChange,
  onSelectOracle,
  selectedForBatch,
  onToggleBatchSelection,
  isSelectionMode,
}: OracleGridProps) {
  const filteredStats = useMemo(() => {
    return stats.filter((s) => s.ticker.toLowerCase().includes(searchQuery.toLowerCase()))
  }, [stats, searchQuery])

  return (
    <section className="space-y-6">
      <div className="flex flex-col md:flex-row justify-between items-center gap-4">
        <div className="relative w-full md:w-96">
          <span className="material-icons-round absolute left-4 top-1/2 -translate-y-1/2 text-slate-400">
            search
          </span>
          <input
            className="w-full pl-12 pr-4 py-3 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl focus:ring-2 focus:ring-primary focus:border-transparent outline-none transition-all"
            placeholder="Search tickers..."
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-6">
        {filteredStats.map((s) => (
          <div
            key={s.ticker}
            onClick={() => {
              if (isSelectionMode) {
                onToggleBatchSelection(s.ticker)
              } else {
                onSelectOracle(s.ticker)
              }
            }}
            className={cn(
              'group bg-white dark:bg-slate-900 rounded-2xl border p-6 hover:shadow-xl transition-all duration-300 cursor-pointer relative overflow-hidden',
              isSelectionMode && selectedForBatch.includes(s.ticker)
                ? 'border-primary ring-2 ring-primary/20'
                : 'border-slate-200 dark:border-slate-800 hover:border-primary/20',
            )}
          >
            {isSelectionMode ? (
              <div
                className={cn(
                  'absolute top-4 right-4 w-6 h-6 rounded-full border-2 flex items-center justify-center transition-colors z-10',
                  selectedForBatch.includes(s.ticker)
                    ? 'bg-primary border-primary'
                    : 'border-slate-300 dark:border-slate-600 bg-slate-100 dark:bg-slate-800',
                )}
              >
                {selectedForBatch.includes(s.ticker) ? (
                  <span className="material-icons-round text-white text-sm">check</span>
                ) : null}
              </div>
            ) : null}
            <div className="flex justify-between items-start mb-6">
              <div>
                <h3 className="text-2xl font-black text-slate-800 dark:text-white tracking-tight">
                  {s.ticker}
                </h3>
                <div className="mt-1 space-y-0.5">
                  <div className="flex items-center gap-1">
                    <span className="text-[9px] font-bold text-slate-400 uppercase w-10">
                      Asset
                    </span>
                    <span className="text-[10px] font-mono text-slate-400 truncate w-24">
                      {s.assetAddress}
                    </span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        navigator.clipboard.writeText(s.assetAddress)
                      }}
                      className="p-0.5 hover:bg-slate-200 dark:hover:bg-slate-700 rounded transition-colors"
                      title="Copy asset address"
                    >
                      <span
                        className="material-icons-round text-slate-400"
                        style={{ fontSize: '10px' }}
                      >
                        content_copy
                      </span>
                    </button>
                  </div>
                  <div className="flex items-center gap-1">
                    <span className="text-[9px] font-bold text-slate-400 uppercase w-10">
                      Oracle
                    </span>
                    <span className="text-[10px] font-mono text-slate-400 truncate w-24">
                      {s.oracleAddress}
                    </span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        navigator.clipboard.writeText(s.oracleAddress)
                      }}
                      className="p-0.5 hover:bg-slate-200 dark:hover:bg-slate-700 rounded transition-colors"
                      title="Copy oracle address"
                    >
                      <span
                        className="material-icons-round text-slate-400"
                        style={{ fontSize: '10px' }}
                      >
                        content_copy
                      </span>
                    </button>
                  </div>
                </div>
              </div>
              <span
                className={cn(
                  'px-3 py-1 rounded-full text-[10px] font-extrabold uppercase tracking-widest border inline-flex items-center gap-1',
                  s.oracleStatus === 'healthy'
                    ? 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20'
                    : s.oracleStatus === 'warning'
                      ? 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20'
                      : 'bg-amber-500/10 text-amber-500 border-amber-500/20',
                )}
                title={s.statusDetail}
              >
                {s.oracleStatus === 'healthy'
                  ? 'Healthy'
                  : s.oracleStatus === 'warning'
                    ? 'Check'
                    : 'Stale'}
                {s.oracleStatus !== 'healthy' && (
                  <span className="material-icons-round" style={{ fontSize: '12px' }}>
                    help_outline
                  </span>
                )}
              </span>
            </div>
            <div className="space-y-4">
              <div>
                <p className="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-1">
                  On-chain Price
                </p>
                <div className="flex items-baseline justify-between gap-2">
                  <span className="text-3xl font-bold tracking-tighter">
                    ${s.onChainPrice.toFixed(4)}
                  </span>
                  <div className="h-10 w-24">
                    <MiniChart
                      data={s.history}
                      color={
                        s.history.length >= 2 &&
                        s.history[s.history.length - 1].price >= s.history[0].price
                          ? '#10b981'
                          : '#f43f5e'
                      }
                    />
                  </div>
                </div>
              </div>
              <div className="flex justify-between items-end bg-slate-50 dark:bg-slate-800/50 p-3 rounded-lg">
                <div>
                  <p className="text-slate-400 text-[10px] font-bold uppercase tracking-wider">
                    Off-chain
                  </p>
                  <p className="text-lg font-bold text-slate-600 dark:text-slate-300">
                    ${s.offChainPrice.toFixed(4)}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-slate-400 text-[10px] font-bold uppercase tracking-wider">
                    Delta
                  </p>
                  <p
                    className={cn(
                      'text-sm font-bold',
                      s.offChainPrice > s.onChainPrice
                        ? 'text-emerald-500'
                        : s.offChainPrice < s.onChainPrice
                          ? 'text-rose-500'
                          : 'text-slate-500',
                    )}
                  >
                    {s.offChainPrice > s.onChainPrice ? '+' : ''}
                    {(((s.offChainPrice - s.onChainPrice) / s.onChainPrice) * 100).toFixed(4)}%
                  </p>
                </div>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-[10px] font-extrabold uppercase text-slate-400">
                  <span className="tracking-widest">On-Chain Updated</span>
                  <span className="text-primary text-right">
                    <TimeAgo timestamp={s.onChainTimestamp} />
                  </span>
                </div>
                <div className="flex justify-between text-[10px] font-extrabold uppercase text-slate-400">
                  <span className="tracking-widest">Off-Chain Data</span>
                  <span
                    className={cn(
                      'text-right',
                      s.offChainTimestamp > 0 && Date.now() / 1000 - s.offChainTimestamp > 86400
                        ? 'text-rose-500'
                        : 'text-primary',
                    )}
                  >
                    {s.offChainTimestamp > 0
                      ? new Date(s.offChainTimestamp * 1000).toLocaleString()
                      : 'N/A'}
                  </span>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
})
