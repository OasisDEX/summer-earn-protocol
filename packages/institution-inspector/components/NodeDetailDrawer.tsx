'use client'

import { X } from 'lucide-react'
import type { GraphNode } from '@/lib/graph-schema'
import { AddressChip } from './AddressChip'

export function NodeDetailDrawer({ node, onClose }: { node: GraphNode | null; onClose: () => void }) {
  if (!node) return null
  const d = node.data
  const rows: Array<[string, React.ReactNode]> = []
  const push = (k: string, v: unknown) => {
    if (v === undefined || v === null || v === '') return
    rows.push([k, String(v)])
  }
  push('type', node.type)
  push('kind', d.kind)
  push('contractName', d.contractName)
  push('protocol', d.protocol)
  push('institutionId', d.institutionId)
  push('fleetName', d.fleetName)
  push('asset', d.asset)
  if (typeof d.arkCount === 'number') push('arkCount', d.arkCount)
  if (typeof d.delaySeconds === 'number') push('delaySeconds', d.delaySeconds)
  push('source', d.source)
  if (typeof d.existsOnChain === 'boolean') push('existsOnChain', d.existsOnChain)
  if (d.drift) push('drift', d.driftDetail ?? true)
  push('bytes32Id', d.bytes32Id)
  push('futureId', d.futureId)

  return (
    <aside className="absolute right-0 top-0 z-10 flex h-full w-80 flex-col border-l border-outline-variant bg-surface-container shadow-lg">
      <div className="flex items-center justify-between border-b border-outline-variant px-4 py-3">
        <h2 className="truncate text-sm font-semibold text-on-surface" title={d.label}>
          {d.label}
        </h2>
        <button onClick={onClose} className="text-on-surface-variant hover:text-on-surface">
          <X size={16} />
        </button>
      </div>
      <div className="custom-scrollbar flex-1 overflow-y-auto px-4 py-3 text-sm">
        {d.address && (
          <div className="mb-3">
            <div className="mb-1 text-[10px] uppercase tracking-wide text-on-surface-variant">Address</div>
            <AddressChip address={d.address} />
          </div>
        )}
        <dl className="space-y-1.5">
          {rows.map(([k, v]) => (
            <div key={k} className="flex justify-between gap-3">
              <dt className="text-on-surface-variant">{k}</dt>
              <dd className="break-all text-right font-mono text-[11px] text-on-surface">{v}</dd>
            </div>
          ))}
        </dl>
        {d.roles && d.roles.length > 0 && (
          <div className="mt-3">
            <div className="mb-1 text-[10px] uppercase tracking-wide text-on-surface-variant">Roles</div>
            {d.roles.map((r, i) => (
              <div key={i} className="text-[11px] text-on-surface-variant">
                {r.role}: <span className="font-mono">{r.holder}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </aside>
  )
}
