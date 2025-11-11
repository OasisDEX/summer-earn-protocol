import { erc20Abi } from 'viem'
import { useAccount, useReadContract } from 'wagmi'

import { ChainId } from '@/types'

import { stakingRewardsManagerAbi } from '../abis/StakingRewardsManager'

interface UseStakingDataProps {
  stakingRewardsManagerAddress?: string
  fleetAddress: string
  chainId: ChainId
}

export function useStakingData({
  stakingRewardsManagerAddress,
  fleetAddress,
  chainId,
}: UseStakingDataProps) {
  const { address: account } = useAccount()

  // Only run these hooks if we have the staking rewards manager address
  const isEnabled = !!stakingRewardsManagerAddress

  // Get staked balance for the user
  const { data: stakedBalance, refetch: refetchStakedBalance } = useReadContract({
    abi: stakingRewardsManagerAbi,
    address: stakingRewardsManagerAddress as `0x${string}`,
    functionName: 'balanceOf',
    args: account ? [account] : undefined,
    chainId: +chainId,
    query: {
      enabled: isEnabled && !!account,
    },
  })

  // Get total staked supply
  const { data: totalStakedSupply } = useReadContract({
    abi: stakingRewardsManagerAbi,
    address: stakingRewardsManagerAddress as `0x${string}`,
    functionName: 'totalSupply',
    chainId: +chainId,
    query: {
      enabled: isEnabled,
    },
  })

  // Get staking token address (should be the fleet token)
  const { data: stakingTokenAddress } = useReadContract({
    abi: stakingRewardsManagerAbi,
    address: stakingRewardsManagerAddress as `0x${string}`,
    functionName: 'stakingToken',
    chainId: +chainId,
    query: {
      enabled: isEnabled,
    },
  })

  // Get number of reward tokens
  const { data: rewardTokensLength } = useReadContract({
    abi: stakingRewardsManagerAbi,
    address: stakingRewardsManagerAddress as `0x${string}`,
    functionName: 'rewardTokensLength',
    chainId: +chainId,
    query: {
      enabled: isEnabled,
    },
  })

  // Get reward token addresses
  const { data: rewardTokens } = useReadContract({
    abi: stakingRewardsManagerAbi,
    address: stakingRewardsManagerAddress as `0x${string}`,
    functionName: 'rewardTokens',
    args: [BigInt(0)], // Get first reward token for now
    chainId: +chainId,
    query: {
      enabled: isEnabled && !!rewardTokensLength && rewardTokensLength > 0,
    },
  })

  // Get earned rewards for the first reward token
  const { data: earnedRewards, refetch: refetchEarnedRewards } = useReadContract({
    abi: stakingRewardsManagerAbi,
    address: stakingRewardsManagerAddress as `0x${string}`,
    functionName: 'earned',
    args: account && rewardTokens ? [account, rewardTokens] : undefined,
    chainId: +chainId,
    query: {
      enabled: isEnabled && !!account && !!rewardTokens,
    },
  })

  // Get fleet token allowance for staking
  const { data: stakingAllowance, refetch: refetchStakingAllowance } = useReadContract({
    abi: erc20Abi,
    address: fleetAddress as `0x${string}`,
    functionName: 'allowance',
    args:
      account && stakingRewardsManagerAddress
        ? [account, stakingRewardsManagerAddress as `0x${string}`]
        : undefined,
    chainId: +chainId,
    query: {
      enabled: isEnabled && !!account && !!fleetAddress,
    },
  })

  return {
    // Contract addresses
    stakingTokenAddress,
    rewardTokens,

    // Balances and rewards
    stakedBalance: stakedBalance || BigInt(0),
    totalStakedSupply: totalStakedSupply || BigInt(0),
    earnedRewards: earnedRewards || BigInt(0),
    rewardTokensLength: Number(rewardTokensLength) || 0,
    stakingAllowance: stakingAllowance || BigInt(0),

    // Refetch functions
    refetchStakedBalance,
    refetchEarnedRewards,
    refetchStakingAllowance,
  }
}
