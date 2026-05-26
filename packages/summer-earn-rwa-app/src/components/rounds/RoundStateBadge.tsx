import { Pill } from '@/components/ui/Pill'
import { humanRoundState, pillVariantForRound, type RoundStateLabel } from '@/lib/rounds/roundState'

interface Props {
  state: RoundStateLabel | undefined
  /** Whether to use the short label ("Open", "Settling", "Settled") instead of the full sentence. */
  short?: boolean
}

const SHORT: Record<RoundStateLabel, string> = {
  OPENED: 'Open',
  IN_SETTLEMENT: 'Settling',
  SETTLED: 'Settled',
  ROLLED_BACK: 'Rolled back',
  NOT_OPENED: '—',
}

export function RoundStateBadge({ state, short }: Props) {
  if (!state) return <Pill variant="neutral">—</Pill>
  return (
    <Pill variant={pillVariantForRound(state)}>
      {short ? SHORT[state] : humanRoundState(state)}
    </Pill>
  )
}
