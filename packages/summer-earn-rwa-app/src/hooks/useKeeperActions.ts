'use client'

import { useQueryClient } from '@tanstack/react-query'

import { roundsVaultInputAbi } from '@/abis/RoundsVaultInput'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseKeeperActionsProps {
  roundsVaultAddress: `0x${string}`
  chainId: ChainId
}

export function useKeeperActions({ roundsVaultAddress, chainId }: UseKeeperActionsProps) {
  const queryClient = useQueryClient()
  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['rounds', chainId, roundsVaultAddress] })
    queryClient.invalidateQueries({ queryKey: ['rounds-vault-current', chainId, roundsVaultAddress] })
  }

  const nextRound = useTxToast({
    chainId,
    labels: {
      pending: 'Closing current round…',
      success: 'Round advanced — prior round in settlement',
      error: 'nextRound failed',
    },
    onSuccess: invalidate,
  })

  const settle = useTxToast({
    chainId,
    labels: {
      pending: 'Settling round on chain…',
      success: 'Round settled — receipts now claimable',
      error: 'Settle failed',
    },
    onSuccess: invalidate,
  })

  const retry = useTxToast({
    chainId,
    labels: {
      pending: 'Retrying past round…',
      success: 'Round queued for settlement again',
      error: 'Retry failed',
    },
    onSuccess: invalidate,
  })

  return {
    nextRound: () => {
      nextRound.beginToast()
      return nextRound.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'nextRound',
      })
    },
    setRoundSettled: (roundId: bigint) => {
      settle.beginToast()
      return settle.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'setRoundSettled',
        args: [roundId],
      })
    },
    setRoundSettledBatch: (roundIds: bigint[]) => {
      settle.beginToast()
      return settle.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'setRoundSettledBatch',
        args: [roundIds],
      })
    },
    retryRound: (roundId: bigint) => {
      retry.beginToast()
      return retry.writeContractAsync({
        address: roundsVaultAddress,
        abi: roundsVaultInputAbi,
        functionName: 'retryRound',
        args: [roundId],
      })
    },
    pending: {
      nextRound: nextRound.isWriting || nextRound.isMining,
      settle: settle.isWriting || settle.isMining,
      retry: retry.isWriting || retry.isMining,
    },
  }
}
