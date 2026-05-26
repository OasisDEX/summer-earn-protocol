'use client'

import { useQueryClient } from '@tanstack/react-query'

import { protocolAccessManagerV2Abi } from '@/abis/ProtocolAccessManagerV2'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'

interface UseRoleActionsProps {
  pamAddress: `0x${string}`
  chainId: ChainId
}

export function useRoleActions({ pamAddress, chainId }: UseRoleActionsProps) {
  const queryClient = useQueryClient()
  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ['institution-roles'] })
    queryClient.invalidateQueries({ queryKey: ['access'] })
  }

  const grant = useTxToast({
    chainId,
    labels: {
      pending: 'Granting role…',
      success: 'Role granted',
      error: 'Grant failed',
    },
    onSuccess: invalidate,
  })

  const revoke = useTxToast({
    chainId,
    labels: {
      pending: 'Revoking role…',
      success: 'Role revoked',
      error: 'Revoke failed',
    },
    onSuccess: invalidate,
  })

  return {
    grantRole: (role: `0x${string}`, account: `0x${string}`) => {
      grant.beginToast()
      return grant.writeContractAsync({
        address: pamAddress,
        abi: protocolAccessManagerV2Abi,
        functionName: 'grantRole',
        args: [role, account],
      })
    },
    revokeRole: (role: `0x${string}`, account: `0x${string}`) => {
      revoke.beginToast()
      return revoke.writeContractAsync({
        address: pamAddress,
        abi: protocolAccessManagerV2Abi,
        functionName: 'revokeRole',
        args: [role, account],
      })
    },
    pending: {
      grant: grant.isWriting || grant.isMining,
      revoke: revoke.isWriting || revoke.isMining,
    },
  }
}
