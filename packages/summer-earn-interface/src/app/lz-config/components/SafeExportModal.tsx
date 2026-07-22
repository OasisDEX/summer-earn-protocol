'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { isAddress } from 'viem'

import { Button, inputBase, labelBase, Modal } from '../../../components/ui'
import { buildSafeTxJsonByChain, downloadSafeTxJson } from '../lib/buildSafeTx'
import type { ChainName, PendingEdit } from '../lib/types'

interface Props {
  pending: PendingEdit[]
  onClose: () => void
}

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
    for (const [chain, json] of Object.entries(built) as [
      ChainName,
      ReturnType<typeof buildSafeTxJsonByChain>[ChainName],
    ][]) {
      if (!json) continue
      downloadSafeTxJson(`safe-tx-${chain}-${json.createdAt}.json`, json)
    }
    onClose()
  }

  return (
    <Modal
      onClose={onClose}
      title="Export Safe Transaction Builder JSON"
      size="lg"
      closeOnBackdrop
      footer={
        <div className="flex items-center justify-end gap-3">
          <Button type="button" variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <button
            type="button"
            onClick={handleDownload}
            disabled={downloadDisabled}
            className={`px-4 py-2 text-sm rounded-lg transition-colors ${
              downloadDisabled
                ? 'bg-white/5 text-on-surface-variant cursor-not-allowed'
                : 'bg-primary/20 text-primary hover:bg-primary/30'
            }`}
          >
            Download
          </button>
        </div>
      }
    >
      <div ref={dialogRef} tabIndex={-1}>
        <div className="mb-4">
          <label className={labelBase}>Safe address</label>
          <input
            type="text"
            value={safeAddress}
            onChange={(e) => setSafeAddress(e.target.value)}
            placeholder="0x… (optional)"
            className={inputBase}
          />
          {safeAddressError ? (
            <div className="text-error text-xs mt-1">{safeAddressError}</div>
          ) : (
            <div className="text-on-surface-variant text-xs mt-1">
              Optional, can be left blank if you&apos;re not sure.
            </div>
          )}
        </div>

        <div>
          <div className="text-xs uppercase tracking-wider text-on-surface-variant mb-2">
            Files to download
          </div>
          {summary.length === 0 ? (
            <div className="text-sm text-on-surface-variant">No pending edits.</div>
          ) : (
            <ul className="space-y-1">
              {summary.map(([chain, count]) => (
                <li
                  key={chain}
                  className="text-xs text-on-surface-variant bg-white/[0.02] border border-white/5 rounded-lg px-3 py-2 font-mono"
                >
                  <span className="capitalize text-on-surface">{chain}</span>
                  <span className="text-on-surface-variant">
                    {' '}
                    — {count} transaction{count === 1 ? '' : 's'} → safe-tx-{chain}-{'<timestamp>'}
                    .json
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </Modal>
  )
}
