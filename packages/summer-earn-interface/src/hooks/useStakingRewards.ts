import { useEffect } from 'react'

import type { ChainId } from '../types'
import { useFleetConfig } from './useFleetConfig'
import { useStakingActions } from './useStakingActions'
import { useStakingData } from './useStakingData'

interface UseStakingRewardsProps {
  fleetAddress: string
  chainId: ChainId
}

export function useStakingRewards({ fleetAddress, chainId }: UseStakingRewardsProps) {
  // Step 1: Get fleet config and staking rewards manager address
  const { fleetConfig, stakingRewardsManagerAddress } = useFleetConfig({
    fleetAddress,
    chainId,
  })

  // Step 2: Get staking data (only if we have the staking rewards manager address)
  const {
    stakingTokenAddress,
    rewardTokens,
    stakedBalance,
    totalStakedSupply,
    earnedRewards,
    rewardTokensLength,
    stakingAllowance,
    refetchStakedBalance,
    refetchEarnedRewards,
    refetchStakingAllowance,
  } = useStakingData({
    stakingRewardsManagerAddress,
    fleetAddress,
    chainId,
  })

  // Step 3: Get staking actions (only if we have the staking rewards manager address)
  const {
    approveStaking,
    stake,
    unstake,
    claimRewards,
    needsStakingApproval,
    isApproveStakingLoading,
    isStakeLoading,
    isUnstakeLoading,
    isClaimLoading,
    isApproveStakingConfirmed,
    isStakeConfirmed,
    isUnstakeConfirmed,
    isClaimConfirmed,
    approveStakingTxHash,
    stakeTxHash,
    unstakeTxHash,
    claimTxHash,
  } = useStakingActions({
    stakingRewardsManagerAddress,
    fleetAddress,
    chainId,
  })

  // Refetch data after successful transactions
  useEffect(() => {
    if (isApproveStakingConfirmed) {
      refetchStakingAllowance()
    }
  }, [isApproveStakingConfirmed, refetchStakingAllowance])

  useEffect(() => {
    if (isStakeConfirmed || isUnstakeConfirmed || isClaimConfirmed) {
      refetchStakedBalance()
      refetchEarnedRewards()
    }
  }, [
    isStakeConfirmed,
    isUnstakeConfirmed,
    isClaimConfirmed,
    refetchStakedBalance,
    refetchEarnedRewards,
  ])

  return {
    // Contract addresses
    stakingRewardsManagerAddress,
    stakingTokenAddress,
    rewardTokens,
    fleetConfig,

    // Balances and rewards
    stakedBalance,
    totalStakedSupply,
    earnedRewards,
    rewardTokensLength,
    stakingAllowance,

    // Actions
    approveStaking,
    stake,
    unstake,
    claimRewards,

    // Helper functions
    needsStakingApproval: (amount: string, fleetDecimals: number = 18) =>
      needsStakingApproval(amount, stakingAllowance, fleetDecimals),

    // Loading states
    isApproveStakingLoading,
    isStakeLoading,
    isUnstakeLoading,
    isClaimLoading,

    // Transaction states
    isApproveStakingConfirmed,
    isStakeConfirmed,
    isUnstakeConfirmed,
    isClaimConfirmed,

    // Transaction hashes
    approveStakingTxHash,
    stakeTxHash,
    unstakeTxHash,
    claimTxHash,
  }
}
