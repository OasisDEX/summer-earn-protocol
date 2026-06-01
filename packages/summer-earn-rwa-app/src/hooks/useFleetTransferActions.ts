'use client'

import { useQueryClient } from '@tanstack/react-query'

import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseFleetTransferActionsProps {
  fleetAddress: `0x${string}`
  chainId: ChainId
}

// Wraps the governor-only fleet-token transferability toggle. The ABI carries
// the no-arg `setFleetTokenTransferability()` which flips the on-chain
// `transfersEnabled` flag — read current state first so callers can label the
// button correctly.
export function useFleetTransferActions({ fleetAddress, chainId }: UseFleetTransferActionsProps) {
  const queryClient = useQueryClient()
  const tx = useTxToast({
    chainId,
    labels: {
      pending: 'Updating transferability…',
      success: 'Fleet-token transferability updated',
      error: 'Update failed',
    },
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: ['fleet-transfers-enabled', chainId, fleetAddress],
      })
      queryClient.invalidateQueries({ queryKey: ['fleetInfo', chainId, fleetAddress] })
    },
  })

  return {
    toggleTransfers: () => {
      tx.beginToast()
      return tx.writeContractAsync({
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'setFleetTokenTransferability',
        args: [],
      })
    },
    pending: tx.isWriting || tx.isMining,
    hash: tx.hash,
    error: tx.error,
  }
}
