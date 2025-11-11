'use client'

import { useState } from 'react'
import { parseUnits } from 'viem'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { VIEM_CHAIN_ENTITIES } from '@/config/chains'

import { fleetCommanderAbi } from '../abis/FleetCommander'
import type { ChainId } from '../types'

interface UseFleetManagementProps {
  fleetAddress: `0x${string}`
  chainId: ChainId
}

export function useFleetManagement({ fleetAddress, chainId }: UseFleetManagementProps) {
  const [pendingOperations, setPendingOperations] = useState<Record<string, boolean>>({})
  const { address } = useAccount()

  // Generic write contract hook for all fleet management operations
  const {
    data: transactionHash,
    writeContract,
    error: writeError,
    isPending: isWritePending,
  } = useWriteContract()

  // Wait for transaction confirmation
  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: confirmError,
  } = useWaitForTransactionReceipt({
    hash: transactionHash,
  })

  const isValidSetup = fleetAddress && fleetAddress !== '0x'

  // Set Minimum Buffer Balance
  const setMinimumBufferBalance = async (newMinimumBalance: string, decimals: number = 18) => {
    if (!isValidSetup) return

    const operationKey = 'setMinimumBufferBalance'
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      const amount = parseUnits(newMinimumBalance, decimals)
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setMinimumBufferBalance',
        args: [amount],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set minimum buffer balance:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Set Fleet Deposit Cap
  const setFleetDepositCap = async (newCap: string, decimals: number = 18) => {
    if (!isValidSetup) return

    const operationKey = 'setFleetDepositCap'
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      const amount = parseUnits(newCap, decimals)
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setFleetDepositCap',
        args: [amount],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set fleet deposit cap:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Set Max Rebalance Operations
  const setMaxRebalanceOperations = async (newMaxOperations: string) => {
    if (!isValidSetup) return

    const operationKey = 'setMaxRebalanceOperations'
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      const operations = BigInt(newMaxOperations)
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setMaxRebalanceOperations',
        args: [operations],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set max rebalance operations:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Set Fleet Token Transferability
  const setFleetTokenTransferability = async () => {
    if (!isValidSetup) return

    const operationKey = 'setFleetTokenTransferability'
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setFleetTokenTransferability',
        args: [],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set fleet token transferability:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Helper function to check if a specific operation is pending
  const isOperationPending = (operationKey: string) => {
    return pendingOperations[operationKey] || false
  }

  return {
    // Fleet management functions
    setMinimumBufferBalance,
    setFleetDepositCap,
    setMaxRebalanceOperations,
    setFleetTokenTransferability,

    // Loading states
    isWritePending,
    isConfirming,
    isConfirmed,
    isOperationPending,

    // Errors
    writeError,
    confirmError,

    // Transaction hash
    transactionHash,
  }
}
