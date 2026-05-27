import { Pill, type PillVariant } from '@/components/ui/Pill'
import type { DisplayStrategyStatus } from '@/types/strategy'

const VARIANT: Record<DisplayStrategyStatus, PillVariant> = {
  ACTIVE: 'active',
  PAUSED: 'paused',
  CANCELLED: 'cancelled',
  COMPLETED: 'completed',
}

const LABEL: Record<DisplayStrategyStatus, string> = {
  ACTIVE: 'Active',
  PAUSED: 'Paused',
  CANCELLED: 'Cancelled',
  COMPLETED: 'Completed',
}

export function StatusBadge({ status }: { status: DisplayStrategyStatus }) {
  return <Pill variant={VARIANT[status]}>{LABEL[status]}</Pill>
}

export function FreshFromChainPill() {
  return (
    <span
      title="Subgraph hasn't caught up yet — showing fresh on-chain state."
      className="inline-flex items-center rounded-pill border border-[var(--info)]/40 bg-[var(--info)]/10 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-[var(--info)]"
    >
      RPC live
    </span>
  )
}
