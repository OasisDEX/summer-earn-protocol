'use client'

import { VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { useState } from 'react'
import { parseUnits } from 'viem'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { erc20Abi } from '../abis/ERC20'
import { fleetCommanderAbi } from '../abis/FleetCommander'

interface UseFleetActionsProps {
  fleetAddress: `0x${string}`
  assetAddress: `0x${string}`
  assetDecimals: number
}

export function useFleetActions({
  fleetAddress,
  assetAddress,
  assetDecimals,
}: UseFleetActionsProps) {
  const [depositPending, setDepositPending] = useState(false)
  const [withdrawPending, setWithdrawPending] = useState(false)
  const [approvePending, setApprovePending] = useState(false)
  const { chainId } = useAccount()
  const { address } = useAccount()

  // Ensure we have valid addresses before proceeding
  const isValidSetup =
    fleetAddress && assetAddress && fleetAddress !== '0x' && assetAddress !== '0x'

  // Approve
  const {
    data: approveHash,
    writeContract: writeApprove,
    error: approveError,
    isPending: isApproveWritePending,
  } = useWriteContract()

  // Deposit
  const {
    data: depositHash,
    writeContract: writeDeposit,
    error: depositError,
    isPending: isDepositWritePending,
  } = useWriteContract()

  // Withdraw
  const {
    data: withdrawHash,
    writeContract: writeWithdraw,
    error: withdrawError,
    isPending: isWithdrawWritePending,
  } = useWriteContract()

  // Waiting for transactions
  const { isLoading: isApproveLoading } = useWaitForTransactionReceipt({
    hash: approveHash,
  })

  const { isLoading: isDepositLoading } = useWaitForTransactionReceipt({
    hash: depositHash,
  })

  const { isLoading: isWithdrawLoading } = useWaitForTransactionReceipt({
    hash: withdrawHash,
  })

  // Actions
  const approve = async (amount: string) => {
    if (!address || !isValidSetup) return

    setApprovePending(true)
    try {
      const parsedAmount = parseUnits(amount, assetDecimals)
      writeApprove({
        address: assetAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [fleetAddress, parsedAmount],
        chain: VIEM_CHAIN_ENTITIES[chainId as unknown as keyof typeof VIEM_CHAIN_ENTITIES],
        account: address,
      })
    } catch (error) {
      console.error('Error approving tokens:', error)
    } finally {
      setApprovePending(false)
    }
  }

  const deposit = async (amount: string) => {
    if (!address || !isValidSetup) return

    setDepositPending(true)
    try {
      const parsedAmount = parseUnits(amount, assetDecimals)
      writeDeposit({
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'deposit',
        args: [parsedAmount, address],
        chain: VIEM_CHAIN_ENTITIES[chainId as unknown as keyof typeof VIEM_CHAIN_ENTITIES],
        account: address,
      })
    } catch (error) {
      console.error('Error depositing:', error)
    } finally {
      setDepositPending(false)
    }
  }

  const withdraw = async (amount: string) => {
    if (!address || !isValidSetup) return

    setWithdrawPending(true)
    try {
      const parsedAmount = parseUnits(amount, assetDecimals)
      writeWithdraw({
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'withdraw',
        args: [parsedAmount, address, address],
        chain: VIEM_CHAIN_ENTITIES[chainId as unknown as keyof typeof VIEM_CHAIN_ENTITIES],
        account: address,
      })
    } catch (error) {
      console.error('Error withdrawing:', error)
    } finally {
      setWithdrawPending(false)
    }
  }

  return {
    // Actions
    approve,
    deposit,
    withdraw,

    // State
    isApproveLoading: isApproveLoading || isApproveWritePending || approvePending,
    isDepositLoading: isDepositLoading || isDepositWritePending || depositPending,
    isWithdrawLoading: isWithdrawLoading || isWithdrawWritePending || withdrawPending,

    // Errors
    approveError,
    depositError,
    withdrawError,

    // Transaction hashes
    approveHash,
    depositHash,
    withdrawHash,
  }
}
