'use client'

import { useState } from 'react'
import { toast } from 'sonner'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { CHAIN_BLOCK_EXPLORERS, VIEM_CHAIN_ENTITIES } from '@/config/chains'

import { fleetCommanderAbi } from '../abis/FleetCommander'
import { ChainId, RebalanceData } from '../types'

interface UseRebalanceProps {
  fleetAddress: `0x${string}`
  chainId: ChainId
}

export function useRebalance({ fleetAddress, chainId }: UseRebalanceProps) {
  const [rebalancePending, setRebalancePending] = useState(false)

  // Rebalance
  const {
    data: rebalanceHash,
    writeContract: writeRebalance,
    error: rebalanceError,
    isPending: isRebalanceWritePending,
  } = useWriteContract()
  const { address } = useAccount()

  // Waiting for transaction
  const {
    isLoading: isRebalanceLoading,
    isSuccess: isRebalanceSuccess,
    isError: isRebalanceError,
  } = useWaitForTransactionReceipt({
    hash: rebalanceHash,
  })

  const openTx = (hash?: `0x${string}`) => {
    if (!hash) return
    const urlBase = CHAIN_BLOCK_EXPLORERS[chainId]
    const url = `${urlBase}/tx/${hash}`
    window.open(url, '_blank', 'noopener,noreferrer')
  }

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
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: address,
      })
    } catch (error) {
      console.error('Error performing rebalance:', error)
      toast.error('Rebalance failed')
    } finally {
      setRebalancePending(false)
    }
  }

  if (isRebalanceSuccess) {
    toast.success('Rebalance confirmed', {
      action: { label: 'View', onClick: () => openTx(rebalanceHash as `0x${string}`) },
    })
  } else if (isRebalanceError) {
    toast.error('Rebalance failed on-chain')
  }

  return {
    rebalance,
    isRebalanceLoading: isRebalanceLoading || isRebalanceWritePending || rebalancePending,
    rebalanceError,
    rebalanceHash,
  }
}
