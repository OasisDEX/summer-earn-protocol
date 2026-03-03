'use client'

import { useState, useEffect, useCallback } from 'react'
import type { Address } from 'viem'
import { type NetworkType, type TickerStats } from '../../lib/oracle-data'

export interface ActivityEvent {
  transactionHash: string
  blockNumber: string
  timestamp: number
  ticker: string
  oracleAddress: Address
  price: number
  priceTimestamp: number
}

export function ActivityLog({
  selectedNetwork,
  stats,
}: {
  selectedNetwork: NetworkType
  stats: TickerStats[]
}) {
  const [events, setEvents] = useState<ActivityEvent[]>([])
  const [loading, setLoading] = useState(false)
  const [daysFetched, setDaysFetched] = useState(1)
  const [hasMore, setHasMore] = useState(true)

  const fetchEvents = useCallback(
    async (daysBackStart: number, daysBackEnd: number) => {
      if (stats.length === 0) return

      setLoading(true)
      try {
        const response = await fetch('/api/activity', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            network: selectedNetwork,
            daysBackStart,
            daysBackEnd,
            oracles: stats.map((s) => ({ address: s.oracleAddress, ticker: s.ticker })),
          }),
        })

        if (!response.ok) {
          throw new Error('Failed to fetch activity logs')
        }

        const data = await response.json()
        const newEvents: ActivityEvent[] = data.events || []

        setEvents((prev) => {
          // Deduplicate events based on transaction hash to prevent double rendering when clicking load more rapidly
          const existingTxHashes = new Set(prev.map((e) => e.transactionHash))
          const filteredNew = newEvents.filter((e) => !existingTxHashes.has(e.transactionHash))
          return [...prev, ...filteredNew].sort((a, b) =>
            BigInt(b.blockNumber) > BigInt(a.blockNumber) ? 1 : -1,
          )
        })

        setDaysFetched(daysBackEnd)

        if (newEvents.length === 0 && daysBackEnd >= 7) {
          setHasMore(false)
        }
      } catch (e) {
        console.error('Failed to fetch activity logs', e)
      } finally {
        setLoading(false)
      }
    },
    [stats, selectedNetwork],
  )

  // Initial fetch when network or stats change
  useEffect(() => {
    setEvents([])
    setDaysFetched(1)
    setHasMore(true)
    if (stats.length > 0) {
      fetchEvents(0, 1)
    }
  }, [fetchEvents])

  return (
    <div className="bg-white dark:bg-[#0f1623] rounded-xl border border-slate-200 dark:border-primary/10 overflow-hidden shadow-sm">
      <div className="p-6 border-b border-slate-200 dark:border-primary/10 flex justify-between items-center bg-slate-50 dark:bg-transparent">
        <div className="flex items-center gap-3">
          <span className="material-icons-round text-primary">history</span>
          <h3 className="text-lg font-bold text-slate-800 dark:text-white">Activity Log</h3>
        </div>
        <div className="text-sm text-slate-500 font-medium">
          Showing last {daysFetched} day{daysFetched > 1 ? 's' : ''}
        </div>
      </div>

      <div className="p-0">
        <div className="w-full overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b border-slate-200 dark:border-primary/10 text-xs uppercase tracking-wider text-slate-500 dark:text-slate-400 font-bold bg-slate-50/50 dark:bg-primary/5">
                <th className="p-4 pl-6">Time</th>
                <th className="p-4">Asset</th>
                <th className="p-4">Action</th>
                <th className="p-4 text-right">Updated Price</th>
                <th className="p-4 text-right pr-6">Transaction</th>
              </tr>
            </thead>
            <tbody>
              {events.length === 0 && !loading ? (
                <tr>
                  <td colSpan={5} className="p-12 text-center text-slate-500">
                    <span className="material-icons-round text-4xl mb-3 block text-slate-300 dark:text-slate-700">
                      receipt_long
                    </span>
                    No price updates found in the selected timeframe.
                  </td>
                </tr>
              ) : (
                events.map((evt, i) => (
                  <tr
                    key={`${evt.transactionHash}-${i}`}
                    className="border-b border-slate-100 dark:border-primary/5 hover:bg-slate-50 dark:hover:bg-primary/5 transition-colors"
                  >
                    <td className="p-4 pl-6 text-sm">
                      <div className="font-medium text-slate-900 dark:text-slate-200">
                        {new Date(evt.timestamp * 1000).toLocaleString('en-US', {
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </div>
                      <div className="text-xs text-slate-500 mt-1">
                        {evt.blockNumber.toString()}
                      </div>
                    </td>
                    <td className="p-4">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center text-primary font-bold text-xs">
                          {evt.ticker.slice(0, 3)}
                        </div>
                        <span className="font-bold text-slate-900 dark:text-white">
                          {evt.ticker}
                        </span>
                      </div>
                    </td>
                    <td className="p-4">
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-bold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                        Price Updated
                      </span>
                    </td>
                    <td className="p-4 text-right">
                      <span className="font-bold text-slate-900 dark:text-white">
                        ${evt.price.toFixed(4)}
                      </span>
                    </td>
                    <td className="p-4 text-right pr-6">
                      <a
                        href={`https://basescan.org/tx/${evt.transactionHash}`}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center justify-center w-8 h-8 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 hover:bg-primary hover:text-white transition-colors"
                      >
                        <span className="material-icons-round text-sm">open_in_new</span>
                      </a>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {loading && (
          <div className="p-8 flex justify-center">
            <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin"></div>
          </div>
        )}

        {!loading && hasMore && (
          <div className="p-4 border-t border-slate-200 dark:border-primary/10 bg-slate-50 dark:bg-transparent flex justify-center">
            <button
              onClick={() => fetchEvents(daysFetched, daysFetched + 1)}
              className="text-sm font-bold text-primary hover:text-primary/80 transition-colors flex items-center gap-2"
            >
              Load Previous Day <span className="material-icons-round text-sm">expand_more</span>
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
