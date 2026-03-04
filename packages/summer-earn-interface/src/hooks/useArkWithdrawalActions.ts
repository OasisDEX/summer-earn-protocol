'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { Address } from 'viem'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { CHAIN_BLOCK_EXPLORERS, VIEM_CHAIN_ENTITIES } from '@/config/chains'

import { arkWithWithdrawalRequestAbi } from '../abis/ArkWithWithdrawalRequest'
import { ChainId } from '../types'

interface UseArkWithdrawalActionsProps {
  arkAddress: Address
  chainId: ChainId
  onSuccess?: () => void
}

export function useArkWithdrawalActions({
  arkAddress,
  chainId,
  onSuccess,
}: UseArkWithdrawalActionsProps) {
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>()
  const { address } = useAccount()

  const { writeContractAsync, isPending: isWritePending, error: writeError } = useWriteContract()

  const { isLoading: isTxLoading, isSuccess: isTxSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  })

  const chain = VIEM_CHAIN_ENTITIES[chainId]
  const explorerBase = CHAIN_BLOCK_EXPLORERS[chainId]

  const requestWithdrawal = async (amount: bigint) => {
    if (!address) {
      toast.error('Connect wallet first')
      return
    }
    try {
      const hash = await writeContractAsync({
        address: arkAddress,
        abi: arkWithWithdrawalRequestAbi,
        functionName: 'requestWithdrawal',
        args: [amount],
        chain,
        account: address,
      })
      setTxHash(hash)
      toast.success('Request withdrawal submitted', {
        action: explorerBase
          ? {
              label: 'View',
              onClick: () => window.open(`${explorerBase}/tx/${hash}`, '_blank'),
            }
          : undefined,
      })
    } catch (err) {
      console.error('requestWithdrawal failed:', err)
      toast.error('Request withdrawal failed')
    }
  }

  const claimWithdrawal = async () => {
    if (!address) {
      toast.error('Connect wallet first')
      return
    }
    try {
      const hash = await writeContractAsync({
        address: arkAddress,
        abi: arkWithWithdrawalRequestAbi,
        functionName: 'claimWithdrawal',
        args: [],
        chain,
        account: address,
      })
      setTxHash(hash)
      toast.success('Claim withdrawal submitted', {
        action: explorerBase
          ? {
              label: 'View',
              onClick: () => window.open(`${explorerBase}/tx/${hash}`, '_blank'),
            }
          : undefined,
      })
    } catch (err) {
      console.error('claimWithdrawal failed:', err)
      toast.error('Claim withdrawal failed')
    }
  }

  const sweep = async () => {
    if (!address) {
      toast.error('Connect wallet first')
      return
    }
    try {
      const hash = await writeContractAsync({
        address: arkAddress,
        abi: arkWithWithdrawalRequestAbi,
        functionName: 'sweep',
        args: [],
        chain,
        account: address,
      })
      setTxHash(hash)
      toast.success('Sweep submitted', {
        action: explorerBase
          ? {
              label: 'View',
              onClick: () => window.open(`${explorerBase}/tx/${hash}`, '_blank'),
            }
          : undefined,
      })
    } catch (err) {
      console.error('sweep failed:', err)
      toast.error('Sweep failed')
    }
  }

  // Clear tx hash and notify on success
  if (isTxSuccess && txHash) {
    onSuccess?.()
    setTxHash(undefined)
  }

  return {
    requestWithdrawal,
    claimWithdrawal,
    sweep,
    isPending: isWritePending || isTxLoading,
    error: writeError ?? null,
  }
}
