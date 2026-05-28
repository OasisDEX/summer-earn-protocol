'use client'

import { useMemo } from 'react'

import { GlassCard } from '../../../components/GlassCard'
import type { EditAuthResult } from '../hooks/useEditAuthorizations'
import type { ChainName, PendingEdit } from '../lib/types'

interface Props {
  pending: PendingEdit[]
  authorizations: EditAuthResult[]
  onRemove: (index: number) => void
  onClear: () => void
  onExport: () => void
  onSubmit: () => void
}

function describeEdit(e: PendingEdit): string {
  switch (e.kind) {
    case 'setPeer':
      return `setPeer · ${e.oApp} · ${e.sourceChain} → ${e.remoteChain}`
    case 'setSendLibrary':
      return `setSendLibrary · ${e.oApp} · ${e.sourceChain} → ${e.remoteChain}`
    case 'setReceiveLibrary':
      return `setReceiveLibrary · ${e.oApp} · ${e.sourceChain} → ${e.remoteChain}`
    case 'setSendConfig':
      return `setSendConfig · ${e.oApp} · ${e.sourceChain} → ${e.remoteChain}`
    case 'setReceiveConfig':
      return `setReceiveConfig · ${e.oApp} · ${e.sourceChain} → ${e.remoteChain}`
    case 'setDelegate':
      return `setDelegate · ${e.oApp} · ${e.sourceChain}`
    case 'setEnforcedOptions':
      return `setEnforcedOptions · ${e.oApp} · ${e.sourceChain}`
  }
}

interface GroupedItem {
  edit: PendingEdit
  originalIndex: number
}

export function PendingChangesCart({
  pending,
  authorizations,
  onRemove,
  onClear,
  onExport,
  onSubmit,
}: Props) {
  const grouped = useMemo(() => {
    const map = new Map<ChainName, GroupedItem[]>()
    pending.forEach((edit, originalIndex) => {
      const list = map.get(edit.sourceChain) ?? []
      list.push({ edit, originalIndex })
      map.set(edit.sourceChain, list)
    })
    return Array.from(map.entries())
  }, [pending])

  const authorizedCount = useMemo(
    () => authorizations.filter((a) => a.canSubmit).length,
    [authorizations],
  )

  return (
    <div className="fixed bottom-4 right-4 z-30 w-[420px] max-w-[90vw]">
      <GlassCard>
        <header className="flex items-center justify-between mb-3">
          <h4 className="text-sm font-semibold text-white">Pending changes ({pending.length})</h4>
          <button
            type="button"
            onClick={onClear}
            className="text-xs text-slate-400 hover:text-white transition-colors"
          >
            Clear all
          </button>
        </header>

        <div className="space-y-3 max-h-[40vh] overflow-y-auto pr-1">
          {grouped.map(([chain, items]) => (
            <div key={chain}>
              <div className="flex items-center gap-2 mb-1">
                <span className="text-xs uppercase tracking-wider text-slate-500 capitalize">
                  {chain}
                </span>
                <span className="text-[10px] bg-white/5 border border-white/10 rounded-full px-2 py-0.5 text-slate-400">
                  {items.length}
                </span>
              </div>
              <ul className="space-y-1">
                {items.map(({ edit, originalIndex }) => {
                  const auth = authorizations[originalIndex]
                  return (
                    <li
                      key={originalIndex}
                      className="flex items-center justify-between gap-2 text-xs text-slate-300 bg-white/[0.02] border border-white/5 rounded-lg px-2 py-1.5"
                    >
                      <div className="min-w-0 flex-1">
                        <div className="truncate">{describeEdit(edit)}</div>
                        {auth && !auth.canSubmit && auth.reason ? (
                          <div className="text-[10px] text-slate-500 truncate">{auth.reason}</div>
                        ) : null}
                      </div>
                      {auth?.canSubmit ? (
                        <span
                          className="text-[10px] text-emerald-400 bg-emerald-400/10 border border-emerald-400/20 rounded px-1.5 py-0.5"
                          title="Connected wallet is authorized to submit this edit"
                        >
                          auth
                        </span>
                      ) : null}
                      <button
                        type="button"
                        onClick={() => onRemove(originalIndex)}
                        className="text-slate-500 hover:text-red-400 transition-colors text-base leading-none px-1"
                        aria-label="Remove edit"
                      >
                        ×
                      </button>
                    </li>
                  )
                })}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-3 space-y-2">
          <button
            type="button"
            onClick={onSubmit}
            disabled={authorizedCount === 0}
            className={`w-full px-4 py-2 text-sm rounded-lg transition-colors ${
              authorizedCount === 0
                ? 'bg-white/5 text-slate-500 cursor-not-allowed'
                : 'bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30'
            }`}
          >
            Submit directly
          </button>
          <div className="text-[11px] text-slate-500 -mt-1">
            Submits {authorizedCount} of {pending.length} edits authorized for your wallet.
          </div>
          <button
            type="button"
            onClick={onExport}
            className="w-full px-4 py-2 text-sm rounded-lg bg-primary/20 text-primary hover:bg-primary/30 transition-colors"
          >
            Export Safe transactions
          </button>
        </div>
      </GlassCard>
    </div>
  )
}
