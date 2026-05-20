import type { DisplayStrategyStatus, StrategyStateOnchain } from '@/types/strategy'
import { StrategyStatus } from '@/types/strategy'

// The contract never sets COMPLETED — that's a UI-derived state when the
// strategy has exhausted maxTrades or passed endDate while still ACTIVE.
export function deriveDisplayStatus(
  state: Pick<StrategyStateOnchain, 'status' | 'tradesExecuted'>,
  maxTrades: bigint,
  endDate: bigint,
  nowSeconds = BigInt(Math.floor(Date.now() / 1000)),
): DisplayStrategyStatus {
  if (state.status === StrategyStatus.CANCELLED) return 'CANCELLED'
  if (state.status === StrategyStatus.PAUSED) return 'PAUSED'
  // ACTIVE state — check terminal conditions even if the contract hasn't
  // observed them yet (a strategy stays ACTIVE on-chain until the next
  // executeDCA call reverts with TerminalStateReached).
  if (maxTrades > 0n && state.tradesExecuted >= maxTrades) return 'COMPLETED'
  if (endDate > 0n && nowSeconds >= endDate) return 'COMPLETED'
  return 'ACTIVE'
}
