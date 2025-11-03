'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { parseUnits } from 'viem'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { CHAIN_BLOCK_EXPLORERS, VIEM_CHAIN_ENTITIES } from '@/config/chains'

import { erc20Abi } from '../abis/ERC20'
import { fleetCommanderAbi } from '../abis/FleetCommander'
import type { ChainId } from '../types'

interface UseFleetActionsProps {
  fleetAddress: `0x${string}`
  assetAddress: `0x${string}`
  assetDecimals: number
  chainId: ChainId
}

export function useFleetActions({
  fleetAddress,
  assetAddress,
  assetDecimals,
  chainId,
}: UseFleetActionsProps) {
  const [depositPending, setDepositPending] = useState(false)
  const [withdrawPending, setWithdrawPending] = useState(false)
  const [approvePending, setApprovePending] = useState(false)
  const [approveToastId, setApproveToastId] = useState<string | number | undefined>(undefined)
  const [depositToastId, setDepositToastId] = useState<string | number | undefined>(undefined)
  const [withdrawToastId, setWithdrawToastId] = useState<string | number | undefined>(undefined)
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
  const {
    isLoading: isApproveLoading,
    isSuccess: isApproveSuccess,
    isError: isApproveError,
  } = useWaitForTransactionReceipt({
    hash: approveHash,
  })

  const {
    isLoading: isDepositLoading,
    isSuccess: isDepositSuccess,
    isError: isDepositError,
  } = useWaitForTransactionReceipt({
    hash: depositHash,
  })

  const {
    isLoading: isWithdrawLoading,
    isSuccess: isWithdrawSuccess,
    isError: isWithdrawError,
  } = useWaitForTransactionReceipt({
    hash: withdrawHash,
  })

  const openTx = (hash?: `0x${string}`) => {
    if (!hash) return
    const urlBase = CHAIN_BLOCK_EXPLORERS[chainId]
    const url = `${urlBase}/tx/${hash}`
    window.open(url, '_blank', 'noopener,noreferrer')
  }

  // Toast lifecycle effects
  if (isApproveSuccess && approveToastId) {
    toast.success('Approval confirmed', {
      id: approveToastId,
      action: { label: 'View', onClick: () => openTx(approveHash as `0x${string}`) },
    })
    setApproveToastId(undefined)
  } else if (isApproveError && approveToastId) {
    toast.error('Approval failed on-chain', { id: approveToastId })
    setApproveToastId(undefined)
  }
  if (isDepositSuccess && depositToastId) {
    toast.success('Deposit confirmed', {
      id: depositToastId,
      action: { label: 'View', onClick: () => openTx(depositHash as `0x${string}`) },
    })
    setDepositToastId(undefined)
  } else if (isDepositError && depositToastId) {
    toast.error('Deposit failed on-chain', { id: depositToastId })
    setDepositToastId(undefined)
  }
  if (isWithdrawSuccess && withdrawToastId) {
    toast.success('Withdraw confirmed', {
      id: withdrawToastId,
      action: { label: 'View', onClick: () => openTx(withdrawHash as `0x${string}`) },
    })
    setWithdrawToastId(undefined)
  } else if (isWithdrawError && withdrawToastId) {
    toast.error('Withdraw failed on-chain', { id: withdrawToastId })
    setWithdrawToastId(undefined)
  }

  // Actions
  const approve = async (amount: string) => {
    if (!address || !isValidSetup) return

    setApprovePending(true)
    try {
      const parsedAmount = parseUnits(amount, assetDecimals)
      const id = toast.loading('Approving…')
      setApproveToastId(id)
      writeApprove({
        address: assetAddress,
        abi: erc20Abi,
        functionName: 'approve',
        args: [fleetAddress, parsedAmount],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Error approving tokens:', error)
      toast.error('Approval failed')
    } finally {
      setApprovePending(false)
    }
  }

  const deposit = async (amount: string) => {
    if (!address || !isValidSetup) return

    setDepositPending(true)
    try {
      const parsedAmount = parseUnits(amount, assetDecimals)
      const id = toast.loading('Depositing…')
      setDepositToastId(id)
      writeDeposit({
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'deposit',
        args: [parsedAmount, address],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Error depositing:', error)
      toast.error('Deposit failed')
    } finally {
      setDepositPending(false)
    }
  }

  const withdraw = async (amount: string) => {
    if (!address || !isValidSetup) return

    setWithdrawPending(true)
    try {
      const parsedAmount = parseUnits(amount, assetDecimals)
      const id = toast.loading('Withdrawing…')
      setWithdrawToastId(id)
      writeWithdraw({
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'withdraw',
        args: [parsedAmount, address, address],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Error withdrawing:', error)
      toast.error('Withdraw failed')
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

    // Success flags
    isApproveSuccess,
    isDepositSuccess,
    isWithdrawSuccess,

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
