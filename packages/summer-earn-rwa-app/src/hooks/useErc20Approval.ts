'use client'

import { useQueryClient } from '@tanstack/react-query'

import { erc20Abi } from '@/abis/ERC20'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseErc20ApprovalProps {
  token: `0x${string}`
  spender: `0x${string}`
  chainId: ChainId
  /** Display label (e.g. "USDC"); used in the toast copy only. */
  symbol?: string
}

export function useErc20Approval({ token, spender, chainId, symbol }: UseErc20ApprovalProps) {
  const queryClient = useQueryClient()
  const tx = useTxToast({
    chainId,
    labels: {
      pending: `Approving ${symbol ?? 'token'}…`,
      success: `${symbol ?? 'Token'} approved`,
      error: 'Approval failed',
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['fleetInfo'] })
    },
  })

  function approve(amount: bigint) {
    tx.beginToast()
    return tx.writeContractAsync({
      address: token,
      abi: erc20Abi,
      functionName: 'approve',
      args: [spender, amount],
    })
  }

  return {
    approve,
    isPending: tx.isWriting || tx.isMining,
    hash: tx.hash,
    error: tx.error,
  }
}
