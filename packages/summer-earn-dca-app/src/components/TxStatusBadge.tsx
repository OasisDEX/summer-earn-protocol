import type { DisplayStrategyStatus } from '@/types/strategy'

const STYLE: Record<DisplayStrategyStatus, string> = {
  ACTIVE: 'bg-success/20 text-success border border-success/40',
  PAUSED: 'bg-warning/15 text-warning border border-warning/40',
  CANCELLED: 'bg-danger/15 text-danger border border-danger/40',
  COMPLETED: 'bg-surface-700/60 text-surface-200 border border-surface-600',
}

export function StatusBadge({ status }: { status: DisplayStrategyStatus }) {
  return (
    <span
      className={[
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium',
        STYLE[status],
      ].join(' ')}
    >
      {status}
    </span>
  )
}

export function FreshFromChainPill() {
  return (
    <span
      className="inline-flex items-center rounded-full border border-primary/40 bg-primary/10 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-primary"
      title="Subgraph hasn't caught up yet — showing fresh on-chain state."
    >
      RPC live
    </span>
  )
}
