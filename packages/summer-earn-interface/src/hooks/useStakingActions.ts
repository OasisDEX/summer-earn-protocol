import { toast } from 'sonner'
import { erc20Abi, parseUnits } from 'viem'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { CHAIN_BLOCK_EXPLORERS } from '@/config/chains'
import { ChainId } from '@/types'

import { stakingRewardsManagerAbi } from '../abis/StakingRewardsManager'

interface UseStakingActionsProps {
  stakingRewardsManagerAddress?: string
  fleetAddress: string
  chainId: ChainId
}

export function useStakingActions({
  stakingRewardsManagerAddress,
  fleetAddress,
  chainId,
}: UseStakingActionsProps) {
  const { address: connectedAccount, chain } = useAccount()
  // Contract write functions
  const {
    writeContract: writeApproveStaking,
    isPending: isApproveStakingLoading,
    data: approveStakingTxData,
  } = useWriteContract()
  const {
    writeContract: writeStake,
    isPending: isStakeLoading,
    data: stakeTxData,
  } = useWriteContract()
  const {
    writeContract: writeUnstake,
    isPending: isUnstakeLoading,
    data: unstakeTxData,
  } = useWriteContract()
  const {
    writeContract: writeClaim,
    isPending: isClaimLoading,
    data: claimTxData,
  } = useWriteContract()

  // Transaction receipts
  const {
    isLoading: isApproveStakingConfirming,
    isSuccess: isApproveStakingConfirmed,
    isError: isApproveStakingError,
  } = useWaitForTransactionReceipt({
    hash: approveStakingTxData,
  })

  const {
    isLoading: isStakeConfirming,
    isSuccess: isStakeConfirmed,
    isError: isStakeError,
  } = useWaitForTransactionReceipt({
    hash: stakeTxData,
  })

  const {
    isLoading: isUnstakeConfirming,
    isSuccess: isUnstakeConfirmed,
    isError: isUnstakeError,
  } = useWaitForTransactionReceipt({
    hash: unstakeTxData,
  })

  const {
    isLoading: isClaimConfirming,
    isSuccess: isClaimConfirmed,
    isError: isClaimError,
  } = useWaitForTransactionReceipt({
    hash: claimTxData,
  })

  const openTx = (hash?: `0x${string}`) => {
    if (!hash) return
    const urlBase = CHAIN_BLOCK_EXPLORERS[chainId]
    const url = `${urlBase}/tx/${hash}`
    window.open(url, '_blank', 'noopener,noreferrer')
  }

  // Approve staking function
  const approveStaking = async () => {
    if (!stakingRewardsManagerAddress || !fleetAddress) return

    try {
      toast.loading('Approving staking…', { id: 'approve-staking' })
      writeApproveStaking({
        abi: erc20Abi,
        address: fleetAddress as `0x${string}`,
        functionName: 'approve',
        args: [
          stakingRewardsManagerAddress as `0x${string}`,
          BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'),
        ] as const,
        chain: chain,
        account: connectedAccount,
      })
    } catch (error) {
      console.error('Error approving staking:', error)
      toast.error('Approve staking failed')
    }
  }

  // Stake function
  const stake = async (amount: string, fleetDecimals: number = 18) => {
    if (!stakingRewardsManagerAddress || !amount) return

    try {
      const parsedAmount = parseUnits(amount, fleetDecimals)
      toast.loading('Staking…', { id: 'stake' })
      writeStake({
        abi: stakingRewardsManagerAbi,
        address: stakingRewardsManagerAddress as `0x${string}`,
        functionName: 'stake',
        args: [parsedAmount] as const,
        chain: chain,
        account: connectedAccount,
      })
    } catch (error) {
      console.error('Error staking:', error)
      toast.error('Stake failed')
    }
  }

  // Unstake function
  const unstake = async (amount: string, fleetDecimals: number = 18) => {
    if (!stakingRewardsManagerAddress || !amount) return

    try {
      const parsedAmount = parseUnits(amount, fleetDecimals)
      toast.loading('Unstaking…', { id: 'unstake' })
      writeUnstake({
        abi: stakingRewardsManagerAbi,
        address: stakingRewardsManagerAddress as `0x${string}`,
        functionName: 'unstake',
        args: [parsedAmount] as const,
        chain: chain,
        account: connectedAccount,
      } as Parameters<typeof writeUnstake>[0])
    } catch (error) {
      console.error('Error unstaking:', error)
      toast.error('Unstake failed')
    }
  }

  // Claim rewards function
  const claimRewards = async () => {
    if (!stakingRewardsManagerAddress) return

    try {
      toast.loading('Claiming rewards…', { id: 'claim' })
      writeClaim({
        abi: stakingRewardsManagerAbi,
        address: stakingRewardsManagerAddress as `0x${string}`,
        functionName: 'getReward',
        args: [] as const,
        chain: chain,
        account: connectedAccount,
      } as Parameters<typeof writeClaim>[0])
    } catch (error) {
      console.error('Error claiming rewards:', error)
      toast.error('Claim rewards failed')
    }
  }

  if (isApproveStakingConfirmed) {
    toast.success('Staking approval confirmed', {
      id: 'approve-staking',
      action: { label: 'View', onClick: () => openTx(approveStakingTxData as `0x${string}`) },
    })
  } else if (isApproveStakingError) {
    toast.error('Approve staking failed on-chain', { id: 'approve-staking' })
  }
  if (isStakeConfirmed) {
    toast.success('Stake confirmed', {
      id: 'stake',
      action: { label: 'View', onClick: () => openTx(stakeTxData as `0x${string}`) },
    })
  } else if (isStakeError) {
    toast.error('Stake failed on-chain', { id: 'stake' })
  }
  if (isUnstakeConfirmed) {
    toast.success('Unstake confirmed', {
      id: 'unstake',
      action: { label: 'View', onClick: () => openTx(unstakeTxData as `0x${string}`) },
    })
  } else if (isUnstakeError) {
    toast.error('Unstake failed on-chain', { id: 'unstake' })
  }
  if (isClaimConfirmed) {
    toast.success('Claim confirmed', {
      id: 'claim',
      action: { label: 'View', onClick: () => openTx(claimTxData as `0x${string}`) },
    })
  } else if (isClaimError) {
    toast.error('Claim failed on-chain', { id: 'claim' })
  }

  // Helper functions
  const needsStakingApproval = (
    amount: string,
    stakingAllowance: bigint,
    fleetDecimals: number = 18,
  ) => {
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
