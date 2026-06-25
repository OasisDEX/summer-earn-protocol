'use client'

import { useEffect, useState } from 'react'
import { toast } from 'sonner'
import { useAccount, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import { CHAIN_BLOCK_EXPLORERS, VIEM_CHAIN_ENTITIES } from '@/config/chains'

import { fleetCommanderAbi } from '../abis/FleetCommander'
import { ChainId, RebalanceData } from '../types'

interface UseRebalanceProps {
  fleetAddress: `0x${string}`
  chainId: ChainId
}

/**
 * Builds a readable failure message from a wagmi/viem write error and, when the revert carries a
 * custom-error selector, surfaces the 4-byte selector so it can be decoded with the deployment
 * `pnpm errors:decode <selector>` tool.
 */
function getRevertMessage(error: unknown): string {
  type ViemCause = { data?: unknown; cause?: { data?: unknown } }
  const e = error as
    | { shortMessage?: string; details?: string; message?: string; cause?: ViemCause; data?: unknown }
    | undefined
  if (!e) return 'Rebalance failed'
  const base = e.shortMessage || e.details || e.message || 'Rebalance failed'
  // viem nests the raw revert payload under cause(.cause).data
  const dataHex: unknown = e.cause?.data ?? e.data ?? e.cause?.cause?.data
  if (typeof dataHex === 'string' && /^0x[0-9a-fA-F]{8}/.test(dataHex)) {
    const selector = dataHex.slice(0, 10)
    return base.includes(selector) ? base : `${base} (error selector ${selector})`
  }
  return base
}

export function useRebalance({ fleetAddress, chainId }: UseRebalanceProps) {
  const [rebalancePending, setRebalancePending] = useState(false)

  // Rebalance
  const {
    data: rebalanceHash,
    writeContractAsync: writeRebalance,
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

      // NOTE: writeContractAsync (not writeContract) so simulation/submission errors reject here
      // and reach the catch — otherwise they'd be swallowed into the unused error state and the
      // failure would be silent.
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
      toast.error('Rebalance failed', { description: getRevertMessage(error) })
    } finally {
      setRebalancePending(false)
    }
  }

  // Surface the on-chain receipt outcome. Effects (not render-body calls) so each toast fires once
  // per transaction instead of on every re-render.
  useEffect(() => {
    if (isRebalanceSuccess) {
      toast.success('Rebalance confirmed', {
        action: { label: 'View', onClick: () => openTx(rebalanceHash as `0x${string}`) },
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isRebalanceSuccess])

  useEffect(() => {
    if (isRebalanceError) {
      toast.error('Rebalance failed on-chain', {
        action: rebalanceHash
          ? { label: 'View', onClick: () => openTx(rebalanceHash as `0x${string}`) }
          : undefined,
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isRebalanceError])

  return {
    rebalance,
    isRebalanceLoading: isRebalanceLoading || isRebalanceWritePending || rebalancePending,
    rebalanceError,
    rebalanceHash,
  }
}
