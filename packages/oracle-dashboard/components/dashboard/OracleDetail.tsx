'use client'

import { useState, useEffect, useCallback } from 'react'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { formatDistanceToNow } from 'date-fns'
import { TickerStats } from '../../hooks/useOracleData'
import { MiniChart } from './MiniChart'

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

interface OracleDetailProps {
  oracle: TickerStats
  onBack: () => void
  onTriggerUpdate: () => void
}

export function OracleDetail({ oracle, onBack, onTriggerUpdate }: OracleDetailProps) {
  const [copiedField, setCopiedField] = useState<string | null>(null)

  const copyToClipboard = useCallback((text: string, field: string) => {
    navigator.clipboard.writeText(text)
    setCopiedField(field)
    setTimeout(() => setCopiedField(null), 2000)
  }, [])
  const [timeAgoFormatted, setTimeAgoFormatted] = useState<string | null>(null)
  const [currentSecs, setCurrentSecs] = useState<number>(0)

  useEffect(() => {
    const timeout = setTimeout(() => setCurrentSecs(Date.now() / 1000), 0)
    const update = () => {
      if (oracle.onChainTimestamp > 0) {
        setTimeAgoFormatted(
          formatDistanceToNow(oracle.onChainTimestamp * 1000, { addSuffix: true }),
        )
      } else {
        setTimeAgoFormatted('N/A')
      }
    }
    update()
    const interval = setInterval(() => {
      update()
      setCurrentSecs(Date.now() / 1000)
    }, 1000)
    return () => {
      clearTimeout(timeout)
      clearInterval(interval)
    }
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
              <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">
                  Status
                </p>
                <span
                  className={cn(
                    'font-bold',
                    oracle.oracleStatus === 'healthy'
                      ? 'text-emerald-500'
                      : oracle.oracleStatus === 'warning'
                        ? 'text-yellow-500'
                        : 'text-amber-500',
                  )}
                >
                  {oracle.oracleStatus === 'healthy'
                    ? 'OPERATIONAL'
                    : oracle.oracleStatus === 'warning'
                      ? 'CHECK ORACLE'
                      : 'STALE DATA'}
                </span>
                <p className="text-[10px] text-slate-500 dark:text-slate-400 mt-1">
                  {oracle.statusDetail}
                </p>
              </div>
              <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">
                  Asset Address
                </p>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-mono break-all text-slate-700 dark:text-slate-300">
                    {oracle.assetAddress}
                  </span>
                  <button
                    onClick={() => copyToClipboard(oracle.assetAddress, 'asset')}
                    className="shrink-0 p-1 hover:bg-slate-200 dark:hover:bg-slate-700 rounded transition-colors"
                    title="Copy asset address"
                  >
                    <span className="material-icons-round text-slate-400 text-sm">
                      {copiedField === 'asset' ? 'check' : 'content_copy'}
                    </span>
                  </button>
                </div>
              </div>
              <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">
                  Oracle Address
                </p>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-mono break-all text-slate-700 dark:text-slate-300">
                    {oracle.oracleAddress}
                  </span>
                  <button
                    onClick={() => copyToClipboard(oracle.oracleAddress, 'oracle')}
                    className="shrink-0 p-1 hover:bg-slate-200 dark:hover:bg-slate-700 rounded transition-colors"
                    title="Copy oracle address"
                  >
                    <span className="material-icons-round text-slate-400 text-sm">
                      {copiedField === 'oracle' ? 'check' : 'content_copy'}
                    </span>
                  </button>
                </div>
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
              <div className="space-y-4">
                <div className="space-y-2">
                  <p className="text-slate-400 text-xs font-bold uppercase">
                    On-chain Price (Base)
                  </p>
                  <div className="flex items-baseline gap-2">
                    <p className="text-5xl font-black text-primary">
                      ${oracle.onChainPrice.toFixed(4)}
                    </p>
                    <span className="text-slate-400 text-xs font-mono">USD</span>
                  </div>
                  <p className="text-xs text-slate-400">
                    Updated {timeAgoFormatted !== null ? timeAgoFormatted : 'just now'}
                  </p>
                </div>

                <div className="h-24 w-full bg-slate-50 dark:bg-slate-800/30 rounded-xl p-4 border border-slate-100 dark:border-slate-700/50">
                  <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">
                    Recent Price Trend (Last 10 Rounds)
                  </p>
                  <MiniChart
                    data={oracle.history}
                    color={
                      oracle.history.length >= 2 &&
                      oracle.history[oracle.history.length - 1].price >= oracle.history[0].price
                        ? '#10b981'
                        : '#f43f5e'
                    }
                  />
                </div>
              </div>
              <div className="space-y-2">
                <p className="text-slate-400 text-xs font-bold uppercase">
                  Off-chain Price (Source)
                </p>
                <p className="text-5xl font-black text-slate-700 dark:text-slate-300">
                  ${oracle.offChainPrice.toFixed(4)}
                </p>
                <div className="flex flex-col gap-1">
                  <p className="text-xs text-slate-400">Source: WisdomTree API</p>
                  <p
                    className={cn(
                      'text-[10px] font-bold uppercase',
                      oracle.offChainTimestamp > 0 &&
                        currentSecs > 0 &&
                        currentSecs - oracle.offChainTimestamp > 86400
                        ? 'text-rose-500'
                        : 'text-slate-400',
                    )}
                  >
                    Data Date:{' '}
                    {oracle.offChainTimestamp > 0
                      ? new Date(oracle.offChainTimestamp * 1000).toLocaleString()
                      : 'N/A'}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white dark:bg-background-dark border border-slate-200 dark:border-slate-800 rounded-xl p-6 space-y-4 shadow-sm">
              <h3 className="font-bold uppercase tracking-tighter text-sm flex items-center gap-2">
                <span className="material-icons-round text-primary">description</span> Contract
                Details
              </h3>
              <div className="grid grid-cols-2 gap-4">
                <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                  <p className="text-[10px] font-bold text-slate-400 uppercase mb-1">Description</p>
                  <p className="text-sm font-semibold truncate">{oracle.description || 'N/A'}</p>
                </div>
                <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                  <p className="text-[10px] font-bold text-slate-400 uppercase mb-1">Version</p>
                  <p className="text-sm font-semibold">{oracle.version}</p>
                </div>
                <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700 font-mono">
                  <p className="text-[10px] font-bold text-slate-400 uppercase mb-1">Round ID</p>
                  <p className="text-sm font-semibold">{oracle.latestRoundId.toString()}</p>
                </div>
                <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700 font-mono">
                  <p className="text-[10px] font-bold text-slate-400 uppercase mb-1">
                    Latest Nonce
                  </p>
                  <p className="text-sm font-semibold">{oracle.nonce.toString()}</p>
                </div>
                <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                  <p className="text-[10px] font-bold text-slate-400 uppercase mb-1">
                    Price Decimals
                  </p>
                  <p className="text-sm font-semibold">8</p>
                </div>
              </div>
              <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
                <p className="text-[10px] font-bold text-slate-400 uppercase mb-1">Owner</p>
                <div className="flex items-center justify-between gap-2">
                  <p className="text-[10px] font-mono truncate text-slate-600 dark:text-slate-400">
                    {oracle.owner}
                  </p>
                  <button
                    onClick={() => copyToClipboard(oracle.owner, 'owner')}
                    className="p-1 hover:bg-slate-200 dark:hover:bg-slate-700 rounded transition-colors"
                  >
                    <span className="material-icons-round text-slate-400 text-xs">
                      {copiedField === 'owner' ? 'check' : 'content_copy'}
                    </span>
                  </button>
                </div>
              </div>
            </div>

            <div className="bg-white dark:bg-background-dark border border-slate-200 dark:border-slate-800 rounded-xl p-6 space-y-4 shadow-sm">
              <div className="flex justify-between items-center">
                <h3 className="font-bold uppercase tracking-tighter text-sm flex items-center gap-2">
                  <span className="material-icons-round text-primary">verified_user</span>{' '}
                  Authorized Signers
                </h3>
                <div className="px-2 py-1 rounded bg-primary/10 text-primary text-[10px] font-black tracking-widest uppercase">
                  Threshold: {oracle.threshold}
                </div>
              </div>
              <div className="space-y-2">
                {oracle.signers.length > 0 ? (
                  oracle.signers.map((signer, idx) => (
                    <div
                      key={signer}
                      className="flex items-center justify-between p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700 group"
                    >
                      <div className="flex items-center gap-3 overflow-hidden">
                        <span className="text-[10px] font-bold text-slate-400">#{idx + 1}</span>
                        <p className="text-[10px] font-mono truncate text-slate-600 dark:text-slate-400">
                          {signer}
                        </p>
                      </div>
                      <button
                        onClick={() => copyToClipboard(signer, `signer-${idx}`)}
                        className="opacity-0 group-hover:opacity-100 p-1 hover:bg-slate-200 dark:hover:bg-slate-700 rounded transition-all"
                      >
                        <span className="material-icons-round text-slate-400 text-xs">
                          {copiedField === `signer-${idx}` ? 'check' : 'content_copy'}
                        </span>
                      </button>
                    </div>
                  ))
                ) : (
                  <p className="text-xs text-slate-400 italic text-center py-4">
                    No signers found or fetched
                  </p>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
