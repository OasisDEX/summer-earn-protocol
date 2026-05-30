'use client'

import { useCallback, useState } from 'react'
import { toast } from 'sonner'
import { createPublicClient, type Hex } from 'viem'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { tipJarAbi } from '@/abis/TipJar'
import {
  CHAIN_BLOCK_EXPLORERS,
  CHAIN_RPC_URLS,
  createRpcTransport,
  VIEM_CHAIN_ENTITIES,
} from '@/config/chains'
import type { ChainId } from '@/types'

function openTx(chainId: ChainId, hash: Hex) {
  const base = CHAIN_BLOCK_EXPLORERS[chainId]
  if (!base) return
  window.open(`${base}/tx/${hash}`, '_blank', 'noopener,noreferrer')
}

function awaitReceipt(chainId: ChainId, hash: Hex) {
  const urls = CHAIN_RPC_URLS[chainId]
  const chain = VIEM_CHAIN_ENTITIES[chainId]
  if (!urls || !chain) return Promise.resolve(undefined)
  const client = createPublicClient({ chain, transport: createRpcTransport(urls) })
  return client.waitForTransactionReceipt({ hash })
}

/**
 * Shake actions for the TipJar page. Because the page shows every chain at once
 * but the wallet is on one chain, each action first switches the connected
 * wallet to the action's target chain, then submits and waits for the receipt.
 * `shake` requires the keeper role on-chain — non-keeper calls revert and surface
 * as an error toast.
 */
export function useTipJarActions() {
  const { address, chainId: connectedChainId } = useAccount()
  const { switchChainAsync } = useSwitchChain()
  const { writeContractAsync } = useWriteContract()
  const [pending, setPending] = useState<Record<string, boolean>>({})

  const isPending = useCallback((key: string) => Boolean(pending[key]), [pending])

  const execute = useCallback(
    async (
      key: string,
      label: string,
      targetChainId: ChainId,
      write: () => Promise<Hex>,
      onDone?: () => void,
    ) => {
      if (!address) {
        toast.error('Connect a wallet first')
        return
      }
      const toastId = `tipjar:${key}`
      setPending((p) => ({ ...p, [key]: true }))
      try {
        const target = Number(targetChainId)
        if (connectedChainId !== target) {
          toast.loading('Switching network…', { id: toastId })
          await switchChainAsync({ chainId: target })
        }
        toast.loading(`${label}…`, { id: toastId })
        const hash = await write()
        toast.loading(`${label}: confirming…`, { id: toastId })
        await awaitReceipt(targetChainId, hash)
        toast.success(`${label} confirmed`, {
          id: toastId,
          action: { label: 'View', onClick: () => openTx(targetChainId, hash) },
        })
        onDone?.()
      } catch (err: unknown) {
        const e = err as { shortMessage?: string; message?: string }
        toast.error(`${label} failed: ${e?.shortMessage ?? e?.message ?? String(err)}`, {
          id: toastId,
        })
      } finally {
        setPending((p) => ({ ...p, [key]: false }))
      }
    },
    [address, connectedChainId, switchChainAsync],
  )

  const shake = useCallback(
    (
      targetChainId: ChainId,
      tipJarAddress: `0x${string}`,
      fleetAddress: `0x${string}`,
      onDone?: () => void,
    ) =>
      execute(
        `${tipJarAddress}:${fleetAddress}`,
        'Shake',
        targetChainId,
        () =>
          writeContractAsync({
            abi: tipJarAbi,
            address: tipJarAddress,
            functionName: 'shake',
            args: [fleetAddress],
            chainId: Number(targetChainId),
            chain: VIEM_CHAIN_ENTITIES[targetChainId],
            account: address,
          }),
        onDone,
      ),
    [execute, writeContractAsync, address],
  )

  const shakeAll = useCallback(
    (targetChainId: ChainId, tipJarAddress: `0x${string}`, onDone?: () => void) =>
      execute(
        `${tipJarAddress}:all`,
        'Shake all',
        targetChainId,
        () =>
          writeContractAsync({
            abi: tipJarAbi,
            address: tipJarAddress,
            functionName: 'shakeAll',
            args: [],
            chainId: Number(targetChainId),
            chain: VIEM_CHAIN_ENTITIES[targetChainId],
            account: address,
          }),
        onDone,
      ),
    [execute, writeContractAsync, address],
  )

  return { shake, shakeAll, isPending }
}
