'use client'

import { useEffect, useRef } from 'react'
import { toast } from 'sonner'
import { BaseError, ContractFunctionRevertedError, type Hex } from 'viem'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import type { ChainId } from '@/types/chain'
import { txExplorerUrl } from '@/utils/explorer'

// Map known custom errors to user-facing labels. Falls through to the
// caller-supplied generic label when we don't recognise the revert.
const FRIENDLY_REVERT_LABELS: Record<string, string> = {
  DuplicateStrategy:
    'A strategy with this exact configuration already exists. Change at least one field (e.g. end date or trade amount) to create a new one.',
  CommitmentMismatch: 'Strategy configuration has changed on-chain. Reload and try again.',
  StrategyNotActive: 'Strategy is not active.',
  UnauthorizedAccess: 'Only the strategy owner can do this.',
}

function friendlyRevertLabel(error: unknown): string | undefined {
  if (!(error instanceof BaseError)) return undefined
  const reverted = error.walk((e) => e instanceof ContractFunctionRevertedError) as
    | ContractFunctionRevertedError
    | undefined
  const name = reverted?.data?.errorName ?? reverted?.reason
  if (!name) return undefined
  return FRIENDLY_REVERT_LABELS[name]
}

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
  const {
    writeContract,
    writeContractAsync,
    data: hash,
    isPending: isWriting,
    error: writeError,
  } = useWriteContract()

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
      toast.error(friendlyRevertLabel(e) ?? opts.labels.error, {
        id: toastIdRef.current,
      })
      toastIdRef.current = undefined
    }
    opts.onError?.(e)
  }

  function resetToast() {
    toastIdRef.current = undefined
  }

  useEffect(() => {
    if (writeError && toastIdRef.current !== undefined) {
      toast.error(friendlyRevertLabel(writeError) ?? opts.labels.error, {
        id: toastIdRef.current,
      })
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
      toast.error(friendlyRevertLabel(receiptError) ?? opts.labels.error, {
        id: toastIdRef.current,
      })
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
