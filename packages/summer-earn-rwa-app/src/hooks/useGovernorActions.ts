'use client'

import { useQueryClient } from '@tanstack/react-query'

import { roundsVaultInputAbi } from '@/abis/RoundsVaultInput'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseGovernorActionsProps {
  roundsVaultAddress: `0x${string}`
  chainId: ChainId
}

export function useGovernorActions({ roundsVaultAddress, chainId }: UseGovernorActionsProps) {
  const queryClient = useQueryClient()
  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['rounds', chainId, roundsVaultAddress] })
    queryClient.invalidateQueries({
      queryKey: ['rounds-vault-current', chainId, roundsVaultAddress],
    })
  }

  const rollback = useTxToast({
    chainId,
    labels: {
      pending: 'Rolling back round…',
      success: 'Round rolled back to Open',
      error: 'Rollback failed',
    },
    onSuccess: invalidate,
  })

  const minSize = useTxToast({
    chainId,
    labels: {
      pending: 'Updating minimum position…',
      success: 'Minimum position size updated',
      error: 'Update failed',
    },
    onSuccess: invalidate,
  })

  return {
    emergencyRollbackRound: (roundId: bigint) => {
      rollback.beginToast()
      return rollback.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'emergencyRollbackRound',
        args: [roundId],
      })
    },
    setMinPositionSize: (size: bigint) => {
      minSize.beginToast()
      return minSize.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'setMinPositionSize',
        args: [size],
      })
    },
    pending: {
      rollback: rollback.isWriting || rollback.isMining,
      minSize: minSize.isWriting || minSize.isMining,
    },
  }
}
