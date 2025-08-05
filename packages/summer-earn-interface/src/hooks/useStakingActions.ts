import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { stakingRewardsManagerAbi } from '../abis/StakingRewardsManager'
import { erc20Abi, parseUnits } from 'viem'
import { ChainId } from '@/types'

interface UseStakingActionsProps {
  stakingRewardsManagerAddress?: string
  fleetAddress: string
  chainId: ChainId
}

export function useStakingActions({ stakingRewardsManagerAddress, fleetAddress, chainId  }: UseStakingActionsProps) {
  // Contract write functions
  const { writeContract: writeApproveStaking, isPending: isApproveStakingLoading, data: approveStakingTxData } = useWriteContract()
  const { writeContract: writeStake, isPending: isStakeLoading, data: stakeTxData } = useWriteContract()
  const { writeContract: writeUnstake, isPending: isUnstakeLoading, data: unstakeTxData } = useWriteContract()
  const { writeContract: writeClaim, isPending: isClaimLoading, data: claimTxData } = useWriteContract()

  // Transaction receipts
  const { isLoading: isApproveStakingConfirming, isSuccess: isApproveStakingConfirmed } = useWaitForTransactionReceipt({
    hash: approveStakingTxData,
  })

  const { isLoading: isStakeConfirming, isSuccess: isStakeConfirmed } = useWaitForTransactionReceipt({
    hash: stakeTxData,
  })

  const { isLoading: isUnstakeConfirming, isSuccess: isUnstakeConfirmed } = useWaitForTransactionReceipt({
    hash: unstakeTxData,
  })

  const { isLoading: isClaimConfirming, isSuccess: isClaimConfirmed } = useWaitForTransactionReceipt({
    hash: claimTxData,
  })

  // Approve staking function
  const approveStaking = async () => {
    if (!stakingRewardsManagerAddress || !fleetAddress) return

    try {
      writeApproveStaking({
        abi: erc20Abi,
        address: fleetAddress as `0x${string}`,
        functionName: 'approve',
        args: [stakingRewardsManagerAddress as `0x${string}`, BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')], // Max approval
        chainId: +chainId , 
      } as any)
    } catch (error) {
      console.error('Error approving staking:', error)
    }
  }

  // Stake function
  const stake = async (amount: string, fleetDecimals: number = 18) => {
    if (!stakingRewardsManagerAddress || !amount) return

    try {
      const parsedAmount = parseUnits(amount, fleetDecimals)
      
      writeStake({
        abi: stakingRewardsManagerAbi,
        address: stakingRewardsManagerAddress as `0x${string}`,
        functionName: 'stake',
        args: [parsedAmount],
        chainId: +chainId , 
      } as any)
    } catch (error) {
      console.error('Error staking:', error)
    }
  }

  // Unstake function
  const unstake = async (amount: string, fleetDecimals: number = 18) => {
    if (!stakingRewardsManagerAddress || !amount) return

    try {
      const parsedAmount = parseUnits(amount, fleetDecimals)
      
      writeUnstake({
        abi: stakingRewardsManagerAbi,
        address: stakingRewardsManagerAddress as `0x${string}`,
        functionName: 'unstake',
        args: [parsedAmount],
        chainId: +chainId , 
      } as any)
    } catch (error) {
      console.error('Error unstaking:', error)
    }
  }

  // Claim rewards function
  const claimRewards = async () => {
    if (!stakingRewardsManagerAddress) return

    try {
      writeClaim({
        abi: stakingRewardsManagerAbi,
        address: stakingRewardsManagerAddress as `0x${string}`,
        functionName: 'getReward',
        args: [],
        chainId: +chainId , 
      } as any)
    } catch (error) {
      console.error('Error claiming rewards:', error)
    }
  }

  // Helper functions
  const needsStakingApproval = (amount: string, stakingAllowance: bigint, fleetDecimals: number = 18) => {
    if (!amount || !stakingAllowance) return false
    try {
      const parsedAmount = parseUnits(amount, fleetDecimals)
      return stakingAllowance < parsedAmount
    } catch {
      return false
    }
  }

  return {
    // Actions
    approveStaking,
    stake,
    unstake,
    claimRewards,
    
    // Helper functions
    needsStakingApproval,
    
    // Loading states
    isApproveStakingLoading: isApproveStakingLoading || isApproveStakingConfirming,
    isStakeLoading: isStakeLoading || isStakeConfirming,
    isUnstakeLoading: isUnstakeLoading || isUnstakeConfirming,
    isClaimLoading: isClaimLoading || isClaimConfirming,
    
    // Transaction states
    isApproveStakingConfirmed,
    isStakeConfirmed,
    isUnstakeConfirmed,
    isClaimConfirmed,
    
    // Transaction hashes
    approveStakingTxHash: approveStakingTxData,
    stakeTxHash: stakeTxData,
    unstakeTxHash: unstakeTxData,
    claimTxHash: claimTxData,
  }
}