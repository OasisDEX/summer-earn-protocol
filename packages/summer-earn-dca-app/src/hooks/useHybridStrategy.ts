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
export function useHybridStrategy(chainId: ChainId, strategyIdStr: string | undefined) {
  const subgraphQuery = useStrategyById(chainId, strategyIdStr)
  const strategyIdBig = strategyIdStr ? BigInt(strategyIdStr) : undefined
  const { state: rpcState, isLoading: rpcLoading, refetch: refetchRpc } = useStrategyState(
    chainId,
    strategyIdBig,
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

  return {
    data: merged,
    isLoading: subgraphQuery.isLoading || rpcLoading,
    isError: subgraphQuery.isError,
    refetchSubgraph: subgraphQuery.refetch,
    refetchRpc,
  }
}
