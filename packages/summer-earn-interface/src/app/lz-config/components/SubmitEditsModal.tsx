'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { useSwitchChain } from 'wagmi'

import { GlassCard } from '../../../components/GlassCard'
import { CHAIN_BLOCK_EXPLORERS } from '../../../config/chains'
import type { EditAuthResult } from '../hooks/useEditAuthorizations'
import { type EditStatus, useSubmitEdits } from '../hooks/useSubmitEdits'
import { describeEdit } from '../lib/buildSafeTx'
import { CHAIN_NAME_TO_ID, type PendingEdit } from '../lib/types'

interface Props {
  pending: PendingEdit[]
  authorizations: EditAuthResult[]
  onClose: () => void
}

function statusLabel(status: EditStatus): string {
  switch (status) {
    case 'queued':
      return 'Queued'
    case 'switching-chain':
      return 'Switching chain…'
    case 'awaiting-signature':
      return 'Awaiting signature…'
    case 'confirming':
      return 'Confirming…'
    case 'success':
      return 'Confirmed'
    case 'error':
      return 'Failed'
    case 'skipped':
      return 'Skipped'
  }
}

function statusColorClasses(status: EditStatus): string {
  switch (status) {
    case 'success':
      return 'text-emerald-400 bg-emerald-400/10 border-emerald-400/20'
    case 'switching-chain':
    case 'awaiting-signature':
    case 'confirming':
      return 'text-amber-400 bg-amber-400/10 border-amber-400/20'
    case 'error':
      return 'text-red-400 bg-red-400/10 border-red-400/20'
    case 'skipped':
      return 'text-slate-500 bg-slate-500/10 border-slate-500/20'
    case 'queued':
    default:
      return 'text-slate-400 bg-white/[0.02] border-white/10'
  }
}

export function SubmitEditsModal({ pending, authorizations, onClose }: Props) {
  const { switchChainAsync } = useSwitchChain()

  const skipIndices = useMemo(() => {
    const set = new Set<number>()
    authorizations.forEach((a, i) => {
      if (!a.canSubmit) set.add(i)
    })
    return set
  }, [authorizations])

  const authorizedCount = pending.length - skipIndices.size
  const skippedCount = skipIndices.size

  const { results, running, run } = useSubmitEdits({ edits: pending, skipIndices })

  const [started, setStarted] = useState(false)
  const done = started && !running

  const dialogRef = useRef<HTMLDivElement>(null)

  // focus dialog on mount for screen readers / keyboard users
  useEffect(() => {
    dialogRef.current?.focus()
  }, [])

  // close on Escape (only when not running)
  useEffect(() => {
    function handler(e: KeyboardEvent) {
      if (e.key === 'Escape' && !running) onClose()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [onClose, running])

  function handleStart() {
    setStarted(true)
    void run(switchChainAsync as (args: { chainId: number }) => Promise<unknown>)
  }

  const canStart = authorizedCount > 0 && !running && !started

  function explorerForChain(chain: PendingEdit['sourceChain']): string | null {
    const chainId = CHAIN_NAME_TO_ID[chain]
    return CHAIN_BLOCK_EXPLORERS[chainId] ?? null
  }

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center bg-black/60 p-4"
      onClick={() => {
        if (!running) onClose()
      }}
    >
      <div
        className="w-full max-w-2xl"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="submit-edits-title"
        tabIndex={-1}
        ref={dialogRef}
      >
        <GlassCard>
          <header className="mb-4 flex items-center justify-between gap-4">
            <div>
              <h3 id="submit-edits-title" className="text-lg font-semibold text-white">
                Submit edits directly
              </h3>
              <p className="text-xs text-slate-400 mt-1">
                {authorizedCount} authorized
                {skippedCount > 0 ? ` · ${skippedCount} skipped (not authorized)` : ''}
              </p>
            </div>
            <button
              type="button"
              onClick={() => {
                if (!running) onClose()
              }}
              disabled={running}
              className="text-slate-400 hover:text-white text-2xl leading-none px-2 disabled:opacity-30 disabled:cursor-not-allowed"
              aria-label="Close"
            >
              ×
            </button>
          </header>

          <ul className="space-y-2 max-h-[50vh] overflow-y-auto pr-1 mb-4">
            {pending.map((edit, i) => {
              const r = results[i]
              const status = r?.status ?? (skipIndices.has(i) ? 'skipped' : 'queued')
              const auth = authorizations[i]
              const explorer = explorerForChain(edit.sourceChain)
              return (
                <li
                  key={i}
                  className={`text-xs rounded-lg border px-3 py-2 ${statusColorClasses(status)}`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <div className="text-slate-200 truncate">{describeEdit(edit)}</div>
                      {status === 'skipped' && auth?.reason ? (
                        <div className="text-slate-500 text-[11px] mt-0.5">{auth.reason}</div>
                      ) : null}
                      {r?.error ? (
                        <div className="text-red-400 text-[11px] mt-0.5 break-words">{r.error}</div>
                      ) : null}
                      {r?.txHash && explorer ? (
                        <a
                          href={`${explorer}/tx/${r.txHash}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-emerald-300 hover:text-emerald-200 text-[11px] mt-0.5 inline-block font-mono break-all"
                        >
                          {r.txHash.slice(0, 10)}…{r.txHash.slice(-8)}
                        </a>
                      ) : null}
                    </div>
                    <div className="text-[11px] font-medium whitespace-nowrap shrink-0">
                      {statusLabel(status)}
                    </div>
                  </div>
                </li>
              )
            })}
          </ul>

          <div className="text-[11px] text-slate-500 mb-3 bg-amber-500/5 border border-amber-500/20 rounded-lg px-3 py-2">
            Each transaction must be approved in your wallet. Chain switching prompts may also
            appear.
          </div>

          <footer className="flex items-center justify-end gap-3">
            {!done ? (
              <button
                type="button"
                onClick={() => {
                  if (!running) onClose()
                }}
                disabled={running}
                className="px-4 py-2 text-sm rounded-lg text-slate-300 hover:text-white hover:bg-white/5 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
              >
                Cancel
              </button>
            ) : (
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 text-sm rounded-lg text-slate-300 hover:text-white hover:bg-white/5 transition-colors"
              >
                Close
              </button>
            )}
            {!done ? (
              <button
                type="button"
                onClick={handleStart}
                disabled={!canStart}
                className={`px-4 py-2 text-sm rounded-lg transition-colors ${
                  !canStart
                    ? 'bg-white/5 text-slate-500 cursor-not-allowed'
                    : 'bg-primary/20 text-primary hover:bg-primary/30'
                }`}
              >
                {running ? 'Submitting…' : 'Start submission'}
              </button>
            ) : null}
          </footer>
        </GlassCard>
      </div>
    </div>
  )
}
