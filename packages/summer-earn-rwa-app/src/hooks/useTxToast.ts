'use client'

import { useEffect, useRef } from 'react'
import { toast } from 'sonner'
import { BaseError, ContractFunctionRevertedError, type Hex } from 'viem'
import { useChainId, useSwitchChain, useWaitForTransactionReceipt, useWriteContract } from 'wagmi'

import type { ChainId } from '@/types/chain'
import { txExplorerUrl } from '@/utils/explorer'

// Map known custom errors to user-facing labels. Caller's generic label is
// used for anything we don't recognise.
const FRIENDLY_REVERT_LABELS: Record<string, string> = {
  // Rounds-vault user-facing errors (RoundsVaultBase + ERC4626MultiToken)
  CanOnlyRedeemCurrentRound:
    'Receipts can only be cancelled while the round is still open. Once the keeper closes the round, you must wait for settlement and then claim the exchange asset.',
  CanOnlyRedeemBatchCurrentRound:
    'Batch cancel works only on receipts from the current open round.',
  CannotRedeeemExchangeAssetCurrentRound:
    'You can only claim the exchange asset for past, settled rounds — not the current open round.',
  CannotRedeeemBatchExchangeAssetCurrentRound:
    'You can only claim the exchange asset for past, settled rounds — not the current open round.',
  RoundNotSettled:
    'This round has not been settled yet. Wait for the keeper to call setRoundSettled before claiming.',
  InvalidRoundState: 'This action is not valid for the round in its current state.',
  RoundsVaultPositionTooSmall:
    'Your position after this action would be below the institution-set minimum. Cancel everything or increase the amount.',
  CannotRetryCurrentRound: 'Retry is only for past rounds, not the current open round.',
  MaxDepositExceeded: 'Deposit exceeds the vault cap.',
  MaxRedeemExceeded: 'Redeem exceeds your receipt balance.',
  MaxRedeemBatchExceeded: 'One of the receipts in this batch exceeds your balance.',
  BadRedeemBatchParameters: 'The batch redeem call had mismatched id/amount arrays.',
  CallerCannotRedeem: 'You are not approved to redeem receipts from this owner.',
  CallerCannotRedeemBatch: 'You are not approved to batch-redeem receipts from this owner.',
  NotWhitelisted:
    'This wallet is not on the institution whitelist for this fleet. Contact your institution administrator to be added.',

  // ProtocolAccessManagerV2 whitelist mgmt
  Whitelist_LengthMismatch: 'The whitelist batch arrays must have the same length.',
  Whitelist_BatchTooLarge: 'Whitelist batch is capped at 200 entries per call.',

  // OZ AccessControl
  AccessControlUnauthorizedAccount: 'Your wallet does not hold the role required for this action.',
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
  beginToast: () => void
  endToastOnError: (e: unknown) => void
  resetToast: () => void
  ensureChain: () => Promise<boolean>
}

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

  const connectedChainId = useChainId()
  const { switchChainAsync } = useSwitchChain()
  const targetChainId = Number(opts.chainId)

  // The app has no network switcher and wagmi v3 won't auto-switch, so a write
  // issued while the wallet sits on another chain throws a ChainMismatchError.
  // Callers await ensureChain() before writing to move the wallet onto the
  // institution's chain first; a rejected switch is reported and aborts.
  async function ensureChain(): Promise<boolean> {
    if (connectedChainId === targetChainId) return true
    try {
      await switchChainAsync({ chainId: targetChainId })
      return true
    } catch {
      toast.error('Switch your wallet to the correct network to continue')
      return false
    }
  }

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
    ensureChain,
    writeContract,
    writeContractAsync,
  }
}
