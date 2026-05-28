'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { isAddress } from 'viem'

import { GlassCard } from '../../../components/GlassCard'
import { buildSafeTxJsonByChain, downloadSafeTxJson } from '../lib/buildSafeTx'
import type { ChainName, PendingEdit } from '../lib/types'

interface Props {
  pending: PendingEdit[]
  onClose: () => void
}

const inputCls =
  'w-full bg-white/5 border border-white/10 rounded-lg py-2 px-3 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all text-white placeholder-slate-500'

export function SafeExportModal({ pending, onClose }: Props) {
  const [safeAddress, setSafeAddress] = useState<string>('')
  const dialogRef = useRef<HTMLDivElement>(null)

  // focus dialog on mount for screen readers / keyboard users
  useEffect(() => {
    dialogRef.current?.focus()
  }, [])

  // close on Escape
  useEffect(() => {
    function handler(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose])

  const trimmedSafe = safeAddress.trim()
  const safeAddressError =
    trimmedSafe.length > 0 && !isAddress(trimmedSafe) ? 'invalid address' : null

  const summary = useMemo(() => {
    const byChain = new Map<ChainName, number>()
    for (const edit of pending) {
      byChain.set(edit.sourceChain, (byChain.get(edit.sourceChain) ?? 0) + 1)
    }
    return Array.from(byChain.entries())
  }, [pending])

  const downloadDisabled = pending.length === 0 || Boolean(safeAddressError)

  function handleDownload() {
    if (downloadDisabled) return
    const built = buildSafeTxJsonByChain(pending, trimmedSafe)
    for (const [chain, json] of Object.entries(built) as [ChainName, ReturnType<typeof buildSafeTxJsonByChain>[ChainName]][]) {
      if (!json) continue
      downloadSafeTxJson(`safe-tx-${chain}-${json.createdAt}.json`, json)
    }
    onClose()
  }

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center bg-black/60 p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="safe-export-title"
        tabIndex={-1}
        ref={dialogRef}
      >
        <GlassCard>
          <header className="mb-4 flex items-center justify-between gap-4">
            <h3 id="safe-export-title" className="text-lg font-semibold text-white">
              Export Safe Transaction Builder JSON
            </h3>
            <button
              type="button"
              onClick={onClose}
              className="text-slate-400 hover:text-white text-2xl leading-none px-2"
              aria-label="Close"
            >
              ×
            </button>
          </header>

          <div className="mb-4">
            <label className="block text-xs uppercase tracking-wider text-slate-500 mb-1">
              Safe address
            </label>
            <input
              type="text"
              value={safeAddress}
              onChange={(e) => setSafeAddress(e.target.value)}
              placeholder="0x… (optional)"
              className={inputCls}
            />
            {safeAddressError ? (
              <div className="text-red-400 text-xs mt-1">{safeAddressError}</div>
            ) : (
              <div className="text-slate-500 text-xs mt-1">
                Optional, can be left blank if you&apos;re not sure.
              </div>
            )}
          </div>

          <div className="mb-4">
            <div className="text-xs uppercase tracking-wider text-slate-500 mb-2">
              Files to download
            </div>
            {summary.length === 0 ? (
              <div className="text-sm text-slate-400">No pending edits.</div>
            ) : (
              <ul className="space-y-1">
                {summary.map(([chain, count]) => (
                  <li
                    key={chain}
                    className="text-xs text-slate-300 bg-white/[0.02] border border-white/5 rounded-lg px-3 py-2 font-mono"
                  >
                    <span className="capitalize text-white">{chain}</span>
                    <span className="text-slate-500">
                      {' '}
                      — {count} transaction{count === 1 ? '' : 's'} → safe-tx-{chain}-
                      {'<timestamp>'}.json
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>

          <footer className="flex items-center justify-end gap-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm rounded-lg text-slate-300 hover:text-white hover:bg-white/5 transition-colors"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleDownload}
              disabled={downloadDisabled}
              className={`px-4 py-2 text-sm rounded-lg transition-colors ${
                downloadDisabled
                  ? 'bg-white/5 text-slate-500 cursor-not-allowed'
                  : 'bg-primary/20 text-primary hover:bg-primary/30'
              }`}
            >
              Download
            </button>
          </footer>
        </GlassCard>
      </div>
    </div>
  )
}
