import { useReadContract } from 'wagmi'

import { fleetCommanderConfigAbi } from '../abis/FleetCommanderConfig'
import type { ChainId } from '../types'

interface UseFleetConfigProps {
  fleetAddress: string
  chainId: ChainId
}

export function useFleetConfig({ fleetAddress, chainId }: UseFleetConfigProps) {
  // Get the fleet config from fleet commander
  const {
    data: fleetConfig,
    error: configError,
    isLoading: configLoading,
  } = useReadContract({
    abi: fleetCommanderConfigAbi,
    address: fleetAddress as `0x${string}`,
    functionName: 'getConfig',
    chainId: +chainId,
    query: {
      enabled: !!fleetAddress,
    },
  })

  // Extract staking rewards manager address from config
  const stakingRewardsManagerAddress = fleetConfig?.stakingRewardsManager as string | undefined // stakingRewardsManager is the 5th element (index 4)

  return {
    fleetConfig,
    stakingRewardsManagerAddress,
    configError,
    configLoading,
  }
}
