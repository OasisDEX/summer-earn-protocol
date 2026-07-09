'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { useSwitchChain } from 'wagmi'

import { AddressDisplay, Button, Modal } from '../../../components/ui'
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
      return 'text-success bg-success/10 border-success/20'
    case 'switching-chain':
    case 'awaiting-signature':
    case 'confirming':
      return 'text-warning bg-warning/10 border-warning/20'
    case 'error':
      return 'text-error bg-error/10 border-error/20'
    case 'skipped':
      return 'text-on-surface-variant bg-white/5 border-white/10'
    case 'queued':
    default:
      return 'text-on-surface-variant bg-white/[0.02] border-white/10'
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
    <Modal
      onClose={() => {
        if (!running) onClose()
      }}
      title={
        <div>
          <div>Submit edits directly</div>
          <p className="text-xs text-on-surface-variant mt-1 font-normal">
            {authorizedCount} authorized
            {skippedCount > 0 ? ` · ${skippedCount} skipped (not authorized)` : ''}
          </p>
        </div>
      }
      size="xl"
      closeOnBackdrop
      footer={
        <div className="flex items-center justify-end gap-3">
          {!done ? (
            <Button
              type="button"
              variant="ghost"
              onClick={() => {
                if (!running) onClose()
              }}
              disabled={running}
            >
              Cancel
            </Button>
          ) : (
            <Button type="button" variant="ghost" onClick={onClose}>
              Close
            </Button>
          )}
          {!done ? (
            <button
              type="button"
              onClick={handleStart}
              disabled={!canStart}
              className={`px-4 py-2 text-sm rounded-lg transition-colors ${
                !canStart
                  ? 'bg-white/5 text-on-surface-variant cursor-not-allowed'
                  : 'bg-primary/20 text-primary hover:bg-primary/30'
              }`}
            >
              {running ? 'Submitting…' : 'Start submission'}
            </button>
          ) : null}
        </div>
      }
    >
      <div ref={dialogRef} tabIndex={-1}>
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
                    <div className="text-on-surface truncate">{describeEdit(edit)}</div>
                    {status === 'skipped' && auth?.reason ? (
                      <div className="text-on-surface-variant text-[11px] mt-0.5">
                        {auth.reason}
                      </div>
                    ) : null}
                    {r?.error ? (
                      <div className="text-error text-[11px] mt-0.5 break-words">{r.error}</div>
                    ) : null}
                    {r?.txHash && explorer ? (
                      <a
                        href={`${explorer}/tx/${r.txHash}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-success hover:text-success/80 text-[11px] mt-0.5 inline-block"
                      >
                        <AddressDisplay value={r.txHash} chars={8} />
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

        <div className="text-[11px] text-on-surface-variant mb-3 bg-warning/5 border border-warning/20 rounded-lg px-3 py-2">
          Each transaction must be approved in your wallet. Chain switching prompts may also appear.
        </div>
      </div>
    </Modal>
  )
}
