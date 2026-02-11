import { useMemo, memo } from 'react'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { TickerStats } from '../../hooks/useOracleData'

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
                <p className="text-[10px] font-mono text-slate-400 truncate w-32">
                  {s.assetAddress}
                </p>
              </div>
              <span
                className={cn(
                  'px-3 py-1 rounded-full text-[10px] font-extrabold uppercase tracking-widest border',
                  s.isUpToDate
                    ? 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20'
                    : 'bg-amber-500/10 text-amber-500 border-amber-500/20',
                )}
              >
                {s.isUpToDate ? 'Healthy' : 'Stale'}
              </span>
            </div>
            <div className="space-y-4">
              <div>
                <p className="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-1">
                  On-chain Price
                </p>
                <div className="flex items-baseline gap-2">
                  <span className="text-3xl font-bold tracking-tighter">
                    ${s.onChainPrice.toFixed(4)}
                  </span>
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
                  <p className="text-sm font-bold text-slate-500">
                    {Math.abs(((s.onChainPrice - s.offChainPrice) / s.offChainPrice) * 100).toFixed(
                      4,
                    )}
                    %
                  </p>
                </div>
              </div>
              <div className="space-y-2">
                <div className="flex justify-between text-[10px] font-extrabold uppercase tracking-widest text-slate-400">
                  <span>Last Updated</span>
                  <span className="text-primary">
                    {new Date(s.onChainTimestamp * 1000).toLocaleTimeString()}
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
