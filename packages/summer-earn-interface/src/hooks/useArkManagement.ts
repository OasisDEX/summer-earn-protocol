'use client'

import { useState } from 'react'
import { parseUnits } from 'viem'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { fleetCommanderAbi } from '../abis/FleetCommander'
import { VIEM_CHAIN_ENTITIES } from '../config/chains'
import type { ChainId } from '../types'

interface UseArkManagementProps {
  fleetAddress: `0x${string}`
  chainId: ChainId
}

export function useArkManagement({ fleetAddress, chainId }: UseArkManagementProps) {
  const [pendingOperations, setPendingOperations] = useState<Record<string, boolean>>({})
  const { address } = useAccount()

  // Generic write contract hook for all ark management operations
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

  // Set Ark Deposit Cap
  const setArkDepositCap = async (
    arkAddress: string,
    newDepositCap: string,
    decimals: number = 18,
  ) => {
    if (!isValidSetup || !arkAddress) return

    const operationKey = `setArkDepositCap_${arkAddress}`
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      const amount = parseUnits(newDepositCap, decimals)
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setArkDepositCap',
        args: [arkAddress as `0x${string}`, amount],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set ark deposit cap:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Set Ark Max Deposit Percentage of TVL
  const setArkMaxDepositPercentageOfTVL = async (arkAddress: string, newPercentage: string) => {
    if (!isValidSetup || !arkAddress) return

    const operationKey = `setArkMaxDepositPercentageOfTVL_${arkAddress}`
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      // Convert percentage to WAD format (1% = 1e18, 100% = 100e18)
      // User inputs percentage (e.g., 10 for 10%), we convert to WAD
      const percentageFloat = parseFloat(newPercentage)
      const wadValue = parseUnits(percentageFloat.toString(), 18) // Each percent is 1e18
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setArkMaxDepositPercentageOfTVL',
        args: [arkAddress as `0x${string}`, wadValue],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set ark max deposit percentage:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Set Ark Max Rebalance Outflow
  const setArkMaxRebalanceOutflow = async (
    arkAddress: string,
    newMaxOutflow: string,
    decimals: number = 18,
  ) => {
    if (!isValidSetup || !arkAddress) return

    const operationKey = `setArkMaxRebalanceOutflow_${arkAddress}`
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      const amount = parseUnits(newMaxOutflow, decimals)
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setArkMaxRebalanceOutflow',
        args: [arkAddress as `0x${string}`, amount],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set ark max rebalance outflow:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Set Ark Max Rebalance Inflow
  const setArkMaxRebalanceInflow = async (
    arkAddress: string,
    newMaxInflow: string,
    decimals: number = 18,
  ) => {
    if (!isValidSetup || !arkAddress) return

    const operationKey = `setArkMaxRebalanceInflow_${arkAddress}`
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      const amount = parseUnits(newMaxInflow, decimals)
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'setArkMaxRebalanceInflow',
        args: [arkAddress as `0x${string}`, amount],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to set ark max rebalance inflow:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Add Ark
  const addArk = async (arkAddress: string) => {
    if (!isValidSetup || !arkAddress) return

    const operationKey = `addArk_${arkAddress}`
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'addArk',
        args: [arkAddress as `0x${string}`],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to add ark:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Remove Ark
  const removeArk = async (arkAddress: string) => {
    if (!isValidSetup || !arkAddress) return

    const operationKey = `removeArk_${arkAddress}`
    setPendingOperations((prev) => ({ ...prev, [operationKey]: true }))

    try {
      await writeContract({
        abi: fleetCommanderAbi,
        address: fleetAddress,
        functionName: 'removeArk',
        args: [arkAddress as `0x${string}`],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Failed to remove ark:', error)
    } finally {
      setPendingOperations((prev) => ({ ...prev, [operationKey]: false }))
    }
  }

  // Helper function to check if a specific operation is pending
  const isOperationPending = (operationKey: string) => {
    return pendingOperations[operationKey] || false
  }

  return {
    // Ark cap management functions
    setArkDepositCap,
    setArkMaxDepositPercentageOfTVL,
    setArkMaxRebalanceOutflow,
    setArkMaxRebalanceInflow,
    addArk,
    removeArk,

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
