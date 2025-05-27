'use client'

import { VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { useState } from 'react'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { fleetCommanderAbi } from '../abis/FleetCommander'
import { RebalanceData } from '../types'

interface UseRebalanceProps {
  fleetAddress: `0x${string}`
}

export function useRebalance({ fleetAddress }: UseRebalanceProps) {
  const [rebalancePending, setRebalancePending] = useState(false)

  // Rebalance
  const {
    data: rebalanceHash,
    writeContract: writeRebalance,
    error: rebalanceError,
    isPending: isRebalanceWritePending,
  } = useWriteContract()
  const { chainId } = useAccount()
  const { address } = useAccount()

  // Waiting for transaction
  const { isLoading: isRebalanceLoading } = useWaitForTransactionReceipt({
    hash: rebalanceHash,
  })

  // Rebalance action
  const rebalance = async (rebalanceData: RebalanceData[]) => {
    setRebalancePending(true)
    try {
      // Transform the RebalanceData to match the ABI expectations
      const formattedData = rebalanceData.map((data) => ({
        fromArk: data.fromArk,
        toArk: data.toArk,
        amount: data.amount,
        boardData: data.boardData,
        disembarkData: data.disembarkData,
      }))

      await writeRebalance({
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'rebalance',
        args: [formattedData],
        chain: VIEM_CHAIN_ENTITIES[chainId as unknown as keyof typeof VIEM_CHAIN_ENTITIES],
        account: address,
      })
    } catch (error) {
      console.error('Error performing rebalance:', error)
    } finally {
      setRebalancePending(false)
    }
  }

  return {
    rebalance,
    isRebalanceLoading: isRebalanceLoading || isRebalanceWritePending || rebalancePending,
    rebalanceError,
    rebalanceHash,
  }
}
