'use client'

import { useReadContract } from 'wagmi'

import { fleetCommanderConfigAbi } from '@/abis/FleetCommanderConfig'
import type { ChainId } from '@/types/chain'

interface UseFleetConfigProps {
  fleetAddress: string
  chainId: ChainId
}

export function useFleetConfig({ fleetAddress, chainId }: UseFleetConfigProps) {
  const {
    data: fleetConfig,
    error: configError,
    isLoading: configLoading,
  } = useReadContract({
    abi: fleetCommanderConfigAbi,
    address: fleetAddress as `0x${string}`,
    functionName: 'getConfig',
    chainId: Number(chainId),
    query: {
      enabled: !!fleetAddress,
    },
  })

  const stakingRewardsManagerAddress = (fleetConfig as { stakingRewardsManager?: string })
    ?.stakingRewardsManager

  return {
    fleetConfig,
    stakingRewardsManagerAddress,
    configError,
    configLoading,
  }
}
