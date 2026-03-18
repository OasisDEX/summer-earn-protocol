'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { Address } from 'viem'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { CHAIN_BLOCK_EXPLORERS, VIEM_CHAIN_ENTITIES } from '@/config/chains'

import { wisdomTreeArkAbi } from '../abis/WisdomTreeArk'
import { ChainId } from '../types'

interface UseWisdomTreeActionsProps {
  arkAddress: Address
  chainId: ChainId
  onSuccess?: () => void
}

export function useWisdomTreeActions({
  arkAddress,
  chainId,
  onSuccess,
}: UseWisdomTreeActionsProps) {
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>()
  const { address } = useAccount()

  const { writeContractAsync, isPending: isWritePending, error: writeError } = useWriteContract()

  const { isLoading: isTxLoading, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  })

  const chain = VIEM_CHAIN_ENTITIES[chainId]
  const explorerBase = CHAIN_BLOCK_EXPLORERS[chainId]

  const clearPendingDeposit = async () => {
    if (!address) {
      toast.error('Connect wallet first')
      return
    }
    try {
      const hash = await writeContractAsync({
        address: arkAddress,
        abi: wisdomTreeArkAbi,
        functionName: 'clearPendingDeposit',
        args: [],
        chain,
        account: address,
      })
      setTxHash(hash)
      toast.success('Clear pending deposit submitted', {
        action: explorerBase
          ? {
              label: 'View',
              onClick: () => window.open(`${explorerBase}/tx/${hash}`, '_blank'),
            }
          : undefined,
      })
    } catch (err) {
      console.error('clearPendingDeposit failed:', err)
      toast.error('Clear pending deposit failed')
    }
  }

  // Clear tx hash and notify on success
  if (isTxSuccess && txHash) {
    onSuccess?.()
    setTxHash(undefined)
  }

  return {
    clearPendingDeposit,
    isPending: isWritePending || isTxLoading,
    error: writeError ?? null,
  }
}
