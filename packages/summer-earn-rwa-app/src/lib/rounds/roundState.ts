import type { PillVariant } from '@/components/ui/Pill'

// On chain (IRoundsVaultBaseEnums.RoundState):
//   0 NotOpened, 1 Opened, 2 InSettlement, 3 Settled
// The subgraph mirrors this directly: post-emergency-rollback rounds go
// back to OPENED, with `Round.rolledBack: true` preserving the historical
// fact. Branch on `round.rolledBack` when you need to surface "this was
// recovered" semantics.

export type RoundStateLabel = 'OPENED' | 'IN_SETTLEMENT' | 'SETTLED' | 'NOT_OPENED'

export const ROUND_STATE_ORDER: RoundStateLabel[] = [
  'NOT_OPENED',
  'OPENED',
  'IN_SETTLEMENT',
  'SETTLED',
]

export function chainRoundStateLabel(state: number): RoundStateLabel {
  switch (state) {
    case 0:
      return 'NOT_OPENED'
    case 1:
      return 'OPENED'
    case 2:
      return 'IN_SETTLEMENT'
    case 3:
      return 'SETTLED'
    default:
      return 'NOT_OPENED'
  }
}

export function pillVariantForRound(state: RoundStateLabel): PillVariant {
  switch (state) {
    case 'OPENED':
      return 'active'
    case 'IN_SETTLEMENT':
      return 'paused'
    case 'SETTLED':
      return 'completed'
    default:
      return 'neutral'
  }
}

export function humanRoundState(state: RoundStateLabel): string {
  switch (state) {
    case 'OPENED':
      return 'Open — accepting deposits'
    case 'IN_SETTLEMENT':
      return 'Settling — locked'
    case 'SETTLED':
      return 'Settled — ready to claim'
    default:
      return 'Not opened'
  }
}
