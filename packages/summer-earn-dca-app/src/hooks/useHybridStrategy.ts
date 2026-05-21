'use client'

import { useMemo } from 'react'

import { useStrategyById } from '@/hooks/useDcaSubgraph'
import { useStrategyState } from '@/hooks/useStrategyState'
import { deriveDisplayStatus } from '@/lib/strategy/status'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'
import { type StrategyStateOnchain, StrategyStatus } from '@/types/strategy'

const STATUS_TO_STRING: Record<StrategyStatus, string> = {
  [StrategyStatus.ACTIVE]: 'ACTIVE',
  [StrategyStatus.PAUSED]: 'PAUSED',
  [StrategyStatus.COMPLETED]: 'COMPLETED',
  [StrategyStatus.CANCELLED]: 'CANCELLED',
}

export interface HybridStrategy {
  subgraph: SubgraphStrategy
  /** RPC-fresh state (may be undefined while loading). */
  rpcState?: StrategyStateOnchain
  /** What the UI should display — RPC wins when present. */
  displayStatus: ReturnType<typeof deriveDisplayStatus>
  displayTradesExecuted: bigint
  displayNextTriggerAt: bigint
  displayLastScheduledAt: bigint
  /** True when RPC and subgraph disagree on a state field. */
  staleness: {
    statusMismatch: boolean
    tradesDelta: bigint
    nextTriggerDelta: bigint
  }
}

// Merges the subgraph entity (immutable config + aggregates + history) with
// the RPC `strategyStates(id)` read. RPC always wins for mutable state fields
// — that's the contract for the "fresh after action" guarantee in the plan.
//
// `initialSubgraph` is optional pre-resolved data from a server component
// loader — useStrategyById uses it as TanStack `initialData` so the first
// client render already has the row.
export function useHybridStrategy(
  chainId: ChainId,
  strategyIdStr: string | undefined,
  initialSubgraph?: SubgraphStrategy | null,
  initialRpcState?: StrategyStateOnchain | null,
) {
  const subgraphQuery = useStrategyById(chainId, strategyIdStr, initialSubgraph)
  const strategyIdBig = strategyIdStr ? BigInt(strategyIdStr) : undefined
  const { state: rpcState, refetch: refetchRpc } = useStrategyState(
    chainId,
    strategyIdBig,
    initialRpcState,
  )

  const merged = useMemo<HybridStrategy | undefined>(() => {
    const sg = subgraphQuery.data
    if (!sg) return undefined

    const sgTrades = BigInt(sg.tradesExecuted)
    const sgNext = BigInt(sg.nextTriggerAt)
    const sgLast = BigInt(sg.lastScheduledAt)
    const sgStatusStr = sg.status

    const displayTrades = rpcState?.tradesExecuted ?? sgTrades
    const displayNext = rpcState?.nextTriggerAt ?? sgNext
    const displayLast = rpcState?.lastScheduledAt ?? sgLast
    const rpcStatusStr = rpcState ? STATUS_TO_STRING[rpcState.status] : undefined
    const effectiveStatusEnum = rpcState
      ? rpcState.status
      : sgStatusStr === 'PAUSED'
        ? StrategyStatus.PAUSED
        : sgStatusStr === 'CANCELLED'
          ? StrategyStatus.CANCELLED
          : StrategyStatus.ACTIVE

    const displayStatus = deriveDisplayStatus(
      { status: effectiveStatusEnum, tradesExecuted: displayTrades },
      BigInt(sg.maxTrades),
      BigInt(sg.endDate),
    )

    return {
      subgraph: sg,
      rpcState,
      displayStatus,
      displayTradesExecuted: displayTrades,
      displayNextTriggerAt: displayNext,
      displayLastScheduledAt: displayLast,
      staleness: {
        statusMismatch: Boolean(rpcStatusStr && rpcStatusStr !== sgStatusStr),
        tradesDelta: displayTrades - sgTrades,
        nextTriggerDelta: displayNext - sgNext,
      },
    }
  }, [subgraphQuery.data, rpcState])

  // Loading is anchored entirely on the subgraph — it indexes every mutable
  // field (`status`, `nextTriggerAt`, `lastScheduledAt`, `tradesExecuted`)
  // so the page can paint without ever blocking on RPC. The RPC read exists
  // purely for *freshness-after-action* (e.g. instant feedback after the
  // user clicks Pause) — when it arrives, `displayX` flips from the
  // subgraph value to the RPC value via the `?? sg*` merge above, no
  // visible reload.
  return {
    data: merged,
    isLoading: subgraphQuery.isLoading,
    isError: subgraphQuery.isError,
    refetchSubgraph: subgraphQuery.refetch,
    refetchRpc,
  }
}
