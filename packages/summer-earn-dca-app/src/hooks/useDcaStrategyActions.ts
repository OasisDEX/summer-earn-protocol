'use client'

import { useCallback } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { decodeEventLog, type Hex } from 'viem'
import { useAccount, usePublicClient } from 'wagmi'

import { dcaStrategyManagerAbi } from '@/abis/DCAStrategyManager'
import { DCA_STRATEGY_MANAGER_ADDRESSES } from '@/config/addresses'
import { VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { useTxToast } from '@/hooks/useTxToast'
import type { ChainId } from '@/types/chain'
import type { StrategyConfigTuple } from '@/types/strategy'

interface UseDcaStrategyActionsArgs {
  chainId: ChainId
  onCreated?: (strategyId: bigint, hash: Hex) => void
  onMutated?: (strategyId: bigint, hash: Hex) => void
}

export function useDcaStrategyActions({
  chainId,
  onCreated,
  onMutated,
}: UseDcaStrategyActionsArgs) {
  const { address: owner } = useAccount()
  const publicClient = usePublicClient({ chainId: Number(chainId) })
  const queryClient = useQueryClient()
  const manager = DCA_STRATEGY_MANAGER_ADDRESSES[chainId]

  const invalidateAll = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ['dca'] })
  }, [queryClient])

  const createTx = useTxToast({
    chainId,
    labels: {
      pending: 'Creating DCA strategy…',
      success: 'Strategy created',
      error: 'Strategy creation failed',
    },
    onSuccess: async (hash) => {
      invalidateAll()
      if (!publicClient || !onCreated) return
      try {
        const receipt = await publicClient.getTransactionReceipt({ hash })
        for (const log of receipt.logs) {
          if (log.address.toLowerCase() !== manager.toLowerCase()) continue
          try {
            const decoded = decodeEventLog({
              abi: dcaStrategyManagerAbi,
              data: log.data,
              topics: log.topics,
            })
            if (decoded.eventName === 'StrategyCreated') {
              const sid = (decoded.args as { strategyId: bigint }).strategyId
              onCreated(sid, hash)
              return
            }
          } catch {
            // ignore non-matching logs
          }
        }
      } catch (e) {
        console.warn('createStrategy: failed to parse receipt for strategyId', e)
      }
    },
  })

  const editTx = useTxToast({
    chainId,
    labels: { pending: 'Editing strategy…', success: 'Strategy edited', error: 'Edit failed' },
    onSuccess: (h) => {
      invalidateAll()
      onMutated?.(0n, h)
    },
  })
  const pauseTx = useTxToast({
    chainId,
    labels: { pending: 'Pausing strategy…', success: 'Strategy paused', error: 'Pause failed' },
    onSuccess: (h) => {
      invalidateAll()
      onMutated?.(0n, h)
    },
  })
  const resumeTx = useTxToast({
    chainId,
    labels: {
      pending: 'Resuming strategy…',
      success: 'Strategy resumed',
      error: 'Resume failed',
    },
    onSuccess: (h) => {
      invalidateAll()
      onMutated?.(0n, h)
    },
  })
  const cancelTx = useTxToast({
    chainId,
    labels: {
      pending: 'Cancelling strategy…',
      success: 'Strategy cancelled',
      error: 'Cancel failed',
    },
    onSuccess: (h) => {
      invalidateAll()
      onMutated?.(0n, h)
    },
  })

  async function createStrategy(config: StrategyConfigTuple) {
    if (!owner) return
    createTx.beginToast()
    try {
      await createTx.writeContractAsync({
        address: manager,
        abi: dcaStrategyManagerAbi,
        functionName: 'createStrategy',
        args: [config],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      createTx.endToastOnError(e)
    }
  }

  async function editStrategy(
    strategyId: bigint,
    oldConfig: StrategyConfigTuple,
    newConfig: StrategyConfigTuple,
  ) {
    if (!owner) return
    editTx.beginToast()
    try {
      await editTx.writeContractAsync({
        address: manager,
        abi: dcaStrategyManagerAbi,
        functionName: 'editStrategy',
        args: [strategyId, oldConfig, newConfig],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      editTx.endToastOnError(e)
    }
  }

  async function pauseStrategy(strategyId: bigint, config: StrategyConfigTuple) {
    if (!owner) return
    pauseTx.beginToast()
    try {
      await pauseTx.writeContractAsync({
        address: manager,
        abi: dcaStrategyManagerAbi,
        functionName: 'pauseStrategy',
        args: [strategyId, config],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      pauseTx.endToastOnError(e)
    }
  }

  async function resumeStrategy(strategyId: bigint, config: StrategyConfigTuple) {
    if (!owner) return
    resumeTx.beginToast()
    try {
      await resumeTx.writeContractAsync({
        address: manager,
        abi: dcaStrategyManagerAbi,
        functionName: 'resumeStrategy',
        args: [strategyId, config],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      resumeTx.endToastOnError(e)
    }
  }

  async function cancelStrategy(strategyId: bigint, config: StrategyConfigTuple) {
    if (!owner) return
    cancelTx.beginToast()
    try {
      await cancelTx.writeContractAsync({
        address: manager,
        abi: dcaStrategyManagerAbi,
        functionName: 'cancelStrategy',
        args: [strategyId, config],
        chain: VIEM_CHAIN_ENTITIES[chainId],
        account: owner,
      })
    } catch (e) {
      cancelTx.endToastOnError(e)
    }
  }

  return {
    createStrategy,
    editStrategy,
    pauseStrategy,
    resumeStrategy,
    cancelStrategy,
    createTx,
    editTx,
    pauseTx,
    resumeTx,
    cancelTx,
  }
}
