import type { PillVariant } from '@/components/ui/Pill'

// On chain (IRoundsVaultBaseEnums.RoundState):
//   0 NotOpened, 1 Opened, 2 InSettlement, 3 Settled
// The subgraph also surfaces ROLLED_BACK (state-correction marker) which
// has no on-chain enum representation — it overrides whatever the contract
// would have reported after emergencyRollbackRound.

export type RoundStateLabel = 'OPENED' | 'IN_SETTLEMENT' | 'SETTLED' | 'ROLLED_BACK' | 'NOT_OPENED'

export const ROUND_STATE_ORDER: RoundStateLabel[] = [
  'NOT_OPENED',
  'OPENED',
  'IN_SETTLEMENT',
  'SETTLED',
  'ROLLED_BACK',
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
    case 'ROLLED_BACK':
      return 'cancelled'
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
    case 'ROLLED_BACK':
      return 'Rolled back'
    default:
      return 'Not opened'
  }
}
