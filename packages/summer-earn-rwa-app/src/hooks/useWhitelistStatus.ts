'use client'

import { useReadContract } from 'wagmi'

import { protocolAccessManagerV2Abi } from '@/abis/ProtocolAccessManagerV2'
import type { ChainId } from '@/types/chain'

interface UseWhitelistStatusProps {
  /** ProtocolAccessManagerV2 address for the institution. */
  pamAddress: `0x${string}`
  /** Context — typically the FleetCommander address. */
  contextAddress: `0x${string}`
  account?: `0x${string}`
  chainId: ChainId
}

export function useWhitelistStatus({
  pamAddress,
  contextAddress,
  account,
  chainId,
}: UseWhitelistStatusProps) {
  const isWhitelisted = useReadContract({
    address: pamAddress,
    abi: protocolAccessManagerV2Abi,
    functionName: 'isWhitelisted',
    args: account ? [contextAddress, account] : undefined,
    chainId: Number(chainId),
    query: {
      enabled: !!account,
      staleTime: 30_000,
    },
  })

  const isOpen = useReadContract({
    address: pamAddress,
    abi: protocolAccessManagerV2Abi,
    functionName: 'isWhitelistOpen',
    args: [contextAddress],
    chainId: Number(chainId),
    query: { staleTime: 60_000 },
  })

  return {
    isWhitelisted: (isWhitelisted.data as boolean | undefined) ?? false,
    isWhitelistOpen: (isOpen.data as boolean | undefined) ?? false,
    loading: isWhitelisted.isLoading || isOpen.isLoading,
    refetch: () => Promise.all([isWhitelisted.refetch(), isOpen.refetch()]),
  }
}
