'use client'

import { useQueryClient } from '@tanstack/react-query'

import { protocolAccessManagerV2Abi } from '@/abis/ProtocolAccessManagerV2'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseWhitelistActionsProps {
  pamAddress: `0x${string}`
  /** Context = FleetCommander address (what the vault treats as scope). */
  contextAddress: `0x${string}`
  chainId: ChainId
}

export function useWhitelistActions({
  pamAddress,
  contextAddress,
  chainId,
}: UseWhitelistActionsProps) {
  const queryClient = useQueryClient()
  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['institution-roles'] })
    queryClient.invalidateQueries({ queryKey: ['whitelist'] })
    queryClient.invalidateQueries({ queryKey: ['access'] })
  }

  const single = useTxToast({
    chainId,
    labels: {
      pending: 'Updating whitelist…',
      success: 'Whitelist updated',
      error: 'Whitelist update failed',
    },
    onSuccess: invalidate,
  })

  const batch = useTxToast({
    chainId,
    labels: {
      pending: 'Submitting whitelist batch…',
      success: 'Whitelist batch updated',
      error: 'Whitelist batch failed',
    },
    onSuccess: invalidate,
  })

  const open = useTxToast({
    chainId,
    labels: {
      pending: 'Toggling whitelist mode…',
      success: 'Whitelist mode updated',
      error: 'Update failed',
    },
    onSuccess: invalidate,
  })

  return {
    setWhitelisted: (account: `0x${string}`, allowed: boolean) => {
      single.beginToast()
      return single.writeContractAsync({
        address: pamAddress,
        abi: protocolAccessManagerV2Abi,
        functionName: 'setWhitelisted',
        args: [contextAddress, account, allowed],
      })
    },
    setWhitelistedBatch: (accounts: `0x${string}`[], alloweds: boolean[]) => {
      if (accounts.length !== alloweds.length) {
        throw new Error('accounts and alloweds must have the same length')
      }
      if (accounts.length > 200) {
        throw new Error('Whitelist batch capped at 200 entries per call')
      }
      batch.beginToast()
      return batch.writeContractAsync({
        address: pamAddress,
        abi: protocolAccessManagerV2Abi,
        functionName: 'setWhitelistedBatch',
        args: [contextAddress, accounts, alloweds],
      })
    },
    setWhitelistOpen: (isOpen: boolean) => {
      open.beginToast()
      return open.writeContractAsync({
        address: pamAddress,
        abi: protocolAccessManagerV2Abi,
        functionName: 'setWhitelistOpen',
        args: [contextAddress, isOpen],
      })
    },
    pending: {
      single: single.isWriting || single.isMining,
      batch: batch.isWriting || batch.isMining,
      open: open.isWriting || open.isMining,
    },
  }
}
