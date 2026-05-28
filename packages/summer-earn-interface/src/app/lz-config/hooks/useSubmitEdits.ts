'use client'
import { useCallback, useState } from 'react'
import { toast } from 'sonner'
import type { Address, Hex } from 'viem'
import { useAccount, useSendTransaction } from 'wagmi'

import { editToTx } from '../lib/buildSafeTx'
import { getEndpoint } from '../lib/configReader'
import { CHAIN_NAME_TO_ID, type ChainName, type PendingEdit } from '../lib/types'
import { makePublicClient } from './usePublicClient'

export type EditStatus =
  | 'queued'
  | 'switching-chain'
  | 'awaiting-signature'
  | 'confirming'
  | 'success'
  | 'error'
  | 'skipped'

export interface EditResult {
  edit: PendingEdit
  status: EditStatus
  txHash?: Hex
  error?: string
}

interface UseSubmitEditsOptions {
  edits: PendingEdit[]
  /**
   * Indices in `edits` that the connected wallet is NOT authorized to submit;
   * they will be marked 'skipped' instead of attempted.
   */
  skipIndices: Set<number>
}

type SwitchChainAsync = (args: { chainId: number }) => Promise<unknown>

export function useSubmitEdits({ edits, skipIndices }: UseSubmitEditsOptions) {
  const { address, chainId: connectedChainId } = useAccount()
  const { sendTransactionAsync } = useSendTransaction()

  const [results, setResults] = useState<EditResult[]>(() =>
    edits.map((e, i) => ({
      edit: e,
      status: skipIndices.has(i) ? 'skipped' : 'queued',
    })),
  )
  const [running, setRunning] = useState(false)

  const updateResult = useCallback((i: number, patch: Partial<EditResult>) => {
    setResults((prev) => prev.map((r, idx) => (idx === i ? { ...r, ...patch } : r)))
  }, [])

  const run = useCallback(
    async (switchChainAsync: SwitchChainAsync) => {
      if (!address) {
        toast.error('Connect a wallet first')
        return
      }
      setRunning(true)
      let currentChainId = connectedChainId
      for (let i = 0; i < edits.length; i++) {
        if (skipIndices.has(i)) continue
        const edit = edits[i]
        const targetChainId = Number(CHAIN_NAME_TO_ID[edit.sourceChain])
        const endpoint = getEndpoint(edit.sourceChain)
        if (!endpoint) {
          updateResult(i, { status: 'error', error: 'No LZ endpoint configured for this chain' })
          break
        }
        try {
          if (currentChainId !== targetChainId) {
            updateResult(i, { status: 'switching-chain' })
            await switchChainAsync({ chainId: targetChainId })
            currentChainId = targetChainId
          }
          const { to, data } = editToTx(edit, endpoint as Address)
          updateResult(i, { status: 'awaiting-signature' })
          const hash = await sendTransactionAsync({
            to,
            data,
            chainId: targetChainId,
          })
          updateResult(i, { status: 'confirming', txHash: hash })
          const client = makePublicClient(edit.sourceChain as ChainName)
          if (!client) throw new Error('No public client for chain')
          await client.waitForTransactionReceipt({ hash })
          updateResult(i, { status: 'success' })
          toast.success(`Tx ${i + 1}/${edits.length} confirmed`)
        } catch (err: any) {
          const msg = err?.shortMessage ?? err?.message ?? String(err)
          updateResult(i, { status: 'error', error: msg })
          toast.error(`Tx ${i + 1} failed: ${msg}`)
          // Stop the loop on first error so the user can decide what to do.
          break
        }
      }
      setRunning(false)
    },
    [address, connectedChainId, edits, skipIndices, sendTransactionAsync, updateResult],
  )

  return { results, running, run }
}
