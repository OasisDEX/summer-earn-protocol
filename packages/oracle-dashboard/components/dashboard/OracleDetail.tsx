'use client'

import { useState, useEffect } from 'react'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { TickerStats } from '../../hooks/useOracleData'

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

interface OracleDetailProps {
  oracle: TickerStats
  onBack: () => void
  onTriggerUpdate: () => void
}

export function OracleDetail({ oracle, onBack, onTriggerUpdate }: OracleDetailProps) {
  const [timeAgo, setTimeAgo] = useState<number | null>(null)

  useEffect(() => {
    const update = () => {
      setTimeAgo(Math.floor(Date.now() / 1000 - (oracle.onChainTimestamp || 0)))
    }
    update()
    const interval = setInterval(update, 1000)
    return () => clearInterval(interval)
  }, [oracle.onChainTimestamp])

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="flex items-center gap-4">
        <button onClick={onBack} className="p-2 hover:bg-slate-100 rounded-full transition-colors">
          <span className="material-icons-round">arrow_back</span>
        </button>
        <div>
          <h2 className="text-4xl font-black tracking-tight">{oracle.ticker} / USD</h2>
          <p className="text-slate-500 font-mono text-sm">{oracle.oracleAddress}</p>
        </div>
      </div>

      <div className="grid grid-cols-12 gap-6">
        <div className="col-span-12 lg:col-span-4 space-y-6">
          <div className="bg-white dark:bg-background-dark border border-slate-200 dark:border-slate-800 rounded-xl overflow-hidden shadow-sm p-6 space-y-6">
            <h3 className="font-bold uppercase tracking-tighter text-sm flex items-center gap-2">
              <span className="material-icons-round text-primary">settings</span> Configuration
            </h3>
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-slate-50 border border-slate-100">
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">
                  Status
                </p>
                <span
                  className={cn(
                    'font-bold',
                    oracle.isUpToDate ? 'text-emerald-500' : 'text-amber-500',
                  )}
                >
                  {oracle.isUpToDate ? 'OPERATIONAL' : 'STALE DATA'}
                </span>
              </div>
              <div className="p-4 rounded-xl bg-slate-50 border border-slate-100">
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">
                  Asset Address
                </p>
                <span className="text-xs font-mono break-all">{oracle.assetAddress}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="col-span-12 lg:col-span-8 space-y-6">
          <div className="bg-white dark:bg-background-dark border border-slate-200 dark:border-slate-800 rounded-xl overflow-hidden shadow-sm">
            <div className="px-6 py-5 border-b border-slate-100 flex justify-between items-center">
              <h2 className="font-bold uppercase tracking-tighter text-sm flex items-center gap-2">
                <span className="material-icons-round text-primary">analytics</span> Market Data
              </h2>
              <button
                onClick={onTriggerUpdate}
                className="flex items-center gap-2 px-4 py-2 bg-primary text-white text-xs font-bold rounded-lg hover:shadow-lg transition-all"
              >
                <span className="material-icons-round text-sm">bolt</span> Trigger Update
              </button>
            </div>
            <div className="p-8 grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="space-y-2">
                <p className="text-slate-400 text-xs font-bold uppercase">On-chain Price (Base)</p>
                <p className="text-5xl font-black text-primary">
                  ${oracle.onChainPrice.toFixed(4)}
                </p>
                <p className="text-xs text-slate-400">
                  Updated {timeAgo !== null ? `${timeAgo}s ago` : 'just now'}
                </p>
              </div>
              <div className="space-y-2">
                <p className="text-slate-400 text-xs font-bold uppercase">
                  Off-chain Price (Source)
                </p>
                <p className="text-5xl font-black text-slate-700">
                  ${oracle.offChainPrice.toFixed(4)}
                </p>
                <p className="text-xs text-slate-400">Source: WisdomTree API</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
