'use client'

import { memo } from 'react'
import { Handle, Position, type NodeProps } from '@xyflow/react'
import { Clock, ShieldAlert } from 'lucide-react'
import type { GraphNodeData, NodeType } from '@/lib/graph-schema'
import { AddressChip } from './AddressChip'

type Data = GraphNodeData & { nodeType: NodeType }

// Brand accents from summer-earn-interface. Each type gets a left accent bar + tag color
// that reads against the dark surface card.
const STYLES: Record<NodeType, { accent: string; tag: string }> = {
  institution: { accent: 'border-l-primary', tag: 'text-primary' },
  fleet: { accent: 'border-l-magenta', tag: 'text-magenta' },
  fleetCommander: { accent: 'border-l-violet', tag: 'text-violet' },
  bufferArk: { accent: 'border-l-outline', tag: 'text-on-surface-variant' },
  ark: { accent: 'border-l-secondary', tag: 'text-secondary' },
  roundsVaultInput: { accent: 'border-l-tertiary', tag: 'text-tertiary' },
  roundsVaultOutput: { accent: 'border-l-tertiary', tag: 'text-tertiary' },
  systemContract: { accent: 'border-l-outline', tag: 'text-on-surface-variant' },
  timelock: { accent: 'border-l-error', tag: 'text-error' },
  roleHolder: { accent: 'border-l-outline-variant', tag: 'text-on-surface-variant' },
}

const TAG: Record<NodeType, string> = {
  institution: 'Institution',
  fleet: 'Fleet',
  fleetCommander: 'FleetCommander',
  bufferArk: 'BufferArk',
  ark: 'Ark',
  roundsVaultInput: 'Rounds · Input',
  roundsVaultOutput: 'Rounds · Output',
  systemContract: 'System',
  timelock: 'Timelock',
  roleHolder: 'Role holder',
}

function InspectorNodeImpl({ data, selected }: NodeProps) {
  const d = data as Data
  const s = STYLES[d.nodeType]
  const isConfigOnly = d.source === 'config'

  return (
    <div
      className={`w-[210px] rounded-lg border border-l-4 bg-surface-container px-3 py-2 shadow-md transition ${s.accent} ${
        selected ? 'border-primary ring-2 ring-primary/60' : 'border-outline-variant'
      } ${isConfigOnly ? 'border-dashed' : ''}`}
    >
      <Handle type="target" position={Position.Left} className="!h-2 !w-2 !border-0 !bg-outline" />
      <div className="flex items-center justify-between">
        <span className={`text-[10px] font-semibold uppercase tracking-wide ${s.tag}`}>
          {d.kind ?? TAG[d.nodeType]}
        </span>
        <div className="flex items-center gap-1">
          {typeof d.delaySeconds === 'number' && (
            <span className="inline-flex items-center gap-0.5 rounded bg-error/15 px-1 text-[9px] text-error">
              <Clock size={9} /> {d.delaySeconds}s
            </span>
          )}
          {d.drift && (
            <span title={d.driftDetail ?? 'config/chain drift'}>
              <ShieldAlert size={12} className="text-error" />
            </span>
          )}
        </div>
      </div>

      <div className="mt-0.5 truncate text-sm font-medium text-on-surface" title={d.label}>
        {d.label}
      </div>

      {d.protocol && d.nodeType === 'ark' && (
        <div className="mt-0.5 text-[10px] text-secondary">{d.protocol}</div>
      )}
      {d.nodeType === 'fleet' && (
        <div className="mt-0.5 text-[10px] text-on-surface-variant">
          {d.asset ?? '—'} · {d.arkCount ?? 0} arks
        </div>
      )}

      {d.address && (
        <div className="mt-1">
          <AddressChip address={d.address} />
        </div>
      )}

      <Handle type="source" position={Position.Right} className="!h-2 !w-2 !border-0 !bg-outline" />
    </div>
  )
}

export const InspectorNode = memo(InspectorNodeImpl)
