import { useMemo } from 'react'
import { useReadContract } from 'wagmi'

import { SUMMER_STAKING_ADDRESSES, SUMMER_TOKEN_ADDRESSES } from '../config/environments'
import type { ChainId } from '../types'
import { useEnvironment } from './useEnvironment'

const stakingRewardsAbi = [
  {
    inputs: [{ name: '', type: 'address' }],
    name: 'rewardData',
    outputs: [
      { name: 'periodFinish', type: 'uint256' },
      { name: 'rewardRate', type: 'uint256' },
      { name: 'rewardsDuration', type: 'uint256' },
      { name: 'lastUpdateTime', type: 'uint256' },
      { name: 'rewardPerTokenStored', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

const SUMMER_PRICE_USD = 0.25 // $0.25 per SUMMER token

export function useStakingAPR(chainId: ChainId) {
  const { environment } = useEnvironment()

  // Resolve and sanitize chain id from route param; fall back to Base (8453) if invalid or unmapped
  const rawChainId = Number(chainId)
  const hasMappingFor = (cid: number) =>
    Boolean(
      SUMMER_TOKEN_ADDRESSES[environment]?.[cid] && SUMMER_STAKING_ADDRESSES[environment]?.[cid],
    )
  const chainIdNumber = Number.isFinite(rawChainId) && hasMappingFor(rawChainId) ? rawChainId : 8453

  // Memoize addresses to ensure they update when environment or chainId changes
  const { summerTokenAddress, stakingAddress } = useMemo(
    () => ({
      summerTokenAddress: SUMMER_TOKEN_ADDRESSES[environment]?.[chainIdNumber] as
        | `0x${string}`
        | undefined,
      stakingAddress: SUMMER_STAKING_ADDRESSES[environment]?.[chainIdNumber] as
        | `0x${string}`
        | undefined,
    }),
    [environment, chainIdNumber],
  )

  // Fetch reward data for SUMMER token
  const { data: rewardData } = useReadContract({
    abi: stakingRewardsAbi,
    address: stakingAddress!,
    functionName: 'rewardData',
    args: summerTokenAddress ? [summerTokenAddress] : undefined,
    query: { enabled: Boolean(stakingAddress && summerTokenAddress) },
  })

  // Fetch total weighted supply
  const { data: totalSupply } = useReadContract({
    abi: stakingRewardsAbi,
    address: stakingAddress!,
    functionName: 'totalSupply',
    query: { enabled: Boolean(stakingAddress) },
  })

  // Calculate APR
  const aprData = useMemo(() => {
    if (!rewardData || !totalSupply) {
      return {
        apr: 0,
        annualRewardAmount: 0,
        annualRewardValue: 0,
        totalStakedValue: 0,
        rewardRate: 0n,
        totalWeightedSupply: 0n,
        isActive: false,
      }
    }

    const [periodFinish, rewardRate] = rewardData as [bigint, bigint, bigint, bigint, bigint]
    const weightedSupply = totalSupply as bigint
    // Annual reward amount = rewardRate * seconds in a year
    const SECONDS_PER_YEAR = 365 * 24 * 60 * 60
    const annualRewardAmount = (rewardRate * BigInt(SECONDS_PER_YEAR)) / BigInt(10 ** 18)

    // Annual reward value = annual reward amount * price per token
    const annualRewardValue = Number(formatEther(annualRewardAmount)) * SUMMER_PRICE_USD

    // Total staked value = total weighted supply * price per token
    const totalStakedValue = Number(formatEther(weightedSupply)) * SUMMER_PRICE_USD

    // APR = (annual reward value / total staked value) * 100
    const apr = totalStakedValue > 0 ? (annualRewardValue / totalStakedValue) * 100 : 0

    // Check if rewards are still active
    const now = Math.floor(Date.now() / 1000)
    const isActive = Number(periodFinish) > now

    return {
      apr,
      annualRewardAmount: Number(formatEther(annualRewardAmount)),
      annualRewardValue,
      totalStakedValue,
      rewardRate,
      totalWeightedSupply: weightedSupply,
      isActive,
      periodFinish: Number(periodFinish),
    }
  }, [rewardData, totalSupply, environment])

  return {
    apr: aprData.apr,
    annualRewardAmount: aprData.annualRewardAmount,
    annualRewardValue: aprData.annualRewardValue,
    totalStakedValue: aprData.totalStakedValue,
    rewardRate: aprData.rewardRate,
    totalWeightedSupply: aprData.totalWeightedSupply,
    isActive: aprData.isActive,
    periodFinish: aprData.periodFinish,
  }
}

// Helper function to format ether values
function formatEther(wei: bigint, decimals: number = 18): string {
  const weiStr = wei.toString()
  if (weiStr.length <= decimals) {
    return `0.${weiStr.padStart(decimals, '0')}`
  }
  return `${weiStr.slice(0, -decimals)}.${weiStr.slice(-decimals)}`
}
