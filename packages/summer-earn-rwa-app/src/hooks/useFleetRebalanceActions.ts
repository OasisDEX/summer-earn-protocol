'use client'

import { useQueryClient } from '@tanstack/react-query'

import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseFleetRebalanceActionsProps {
  fleetAddress: `0x${string}`
  chainId: ChainId
}

export interface RebalanceLeg {
  fromArk: `0x${string}`
  toArk: `0x${string}`
  amount: bigint
  boardData: `0x${string}`
  disembarkData: `0x${string}`
}

export function useFleetRebalanceActions({ fleetAddress, chainId }: UseFleetRebalanceActionsProps) {
  const queryClient = useQueryClient()
  const tx = useTxToast({
    chainId,
    labels: {
      pending: 'Submitting rebalance…',
      success: 'Rebalance submitted',
      error: 'Rebalance failed',
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['arks', chainId, fleetAddress] })
      queryClient.invalidateQueries({ queryKey: ['fleetInfo', chainId, fleetAddress] })
    },
  })

  return {
    rebalance: (legs: RebalanceLeg[]) => {
      tx.beginToast()
      return tx.writeContractAsync({
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'rebalance',
        args: [legs],
      })
    },
    pending: tx.isWriting || tx.isMining,
    hash: tx.hash,
    error: tx.error,
  }
}
