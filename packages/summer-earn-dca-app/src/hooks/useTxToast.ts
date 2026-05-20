'use client'

import { useEffect, useRef } from 'react'
import { toast } from 'sonner'
import type { Hex } from 'viem'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import type { ChainId } from '@/types/chain'
import { txExplorerUrl } from '@/utils/explorer'

interface UseTxToastOptions {
  chainId: ChainId
  labels: {
    pending: string
    success: string
    error: string
  }
  onSuccess?: (hash: Hex) => void
  onError?: (error: unknown) => void
}

interface UseTxToastResult {
  hash: Hex | undefined
  isWriting: boolean
  isMining: boolean
  isSuccess: boolean
  isError: boolean
  error: unknown
  /** Starts the toast loading state and returns a setter that the caller invokes after writeContract. */
  beginToast: () => void
  endToastOnError: (e: unknown) => void
  resetToast: () => void
}

// Centralised toast lifecycle around a single wagmi write. Extracted because
// summer-earn-interface re-implements this inline for every action — we factor
// it out so create/edit/pause/resume/cancel + Permit2 sub-actions all share it.
export function useTxToast(opts: UseTxToastOptions): UseTxToastResult & {
  writeContract: ReturnType<typeof useWriteContract>['writeContract']
  writeContractAsync: ReturnType<typeof useWriteContract>['writeContractAsync']
} {
  const { writeContract, writeContractAsync, data: hash, isPending: isWriting, error: writeError } =
    useWriteContract()

  const {
    isLoading: isMining,
    isSuccess,
    isError,
    error: receiptError,
  } = useWaitForTransactionReceipt({ hash })

  const toastIdRef = useRef<string | number | undefined>(undefined)

  function beginToast() {
    const id = toast.loading(opts.labels.pending)
    toastIdRef.current = id
  }

  function endToastOnError(e: unknown) {
    if (toastIdRef.current !== undefined) {
      toast.error(opts.labels.error, { id: toastIdRef.current })
      toastIdRef.current = undefined
    }
    opts.onError?.(e)
  }

  function resetToast() {
    toastIdRef.current = undefined
  }

  useEffect(() => {
    if (writeError && toastIdRef.current !== undefined) {
      toast.error(opts.labels.error, { id: toastIdRef.current })
      toastIdRef.current = undefined
      opts.onError?.(writeError)
    }
  }, [writeError, opts])

  useEffect(() => {
    if (isSuccess && hash && toastIdRef.current !== undefined) {
      toast.success(opts.labels.success, {
        id: toastIdRef.current,
        action: {
          label: 'View',
          onClick: () => window.open(txExplorerUrl(opts.chainId, hash), '_blank'),
        },
      })
      toastIdRef.current = undefined
      opts.onSuccess?.(hash)
    } else if (isError && toastIdRef.current !== undefined) {
      toast.error(opts.labels.error, { id: toastIdRef.current })
      toastIdRef.current = undefined
      opts.onError?.(receiptError)
    }
  }, [isSuccess, isError, hash, receiptError, opts])

  return {
    hash,
    isWriting,
    isMining,
    isSuccess,
    isError,
    error: writeError ?? receiptError ?? null,
    beginToast,
    endToastOnError,
    resetToast,
    writeContract,
    writeContractAsync,
  }
}
