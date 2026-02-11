'use client'

import { useState } from 'react'
import { type Address, type Hex } from 'viem'
import {
  useSignTypedData,
  useWriteContract,
  useConnection,
  useSwitchChain,
  useReadContract,
} from 'wagmi'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { toast } from 'sonner'
import { RWA_ORACLE_ABI } from '../lib/constants'

/** EIP-712 types for RwaOracle price update - must match contract */
const PRICE_UPDATE_TYPES = {
  PriceUpdate: [
    { name: 'price', type: 'int256' },
    { name: 'timestamp', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'oracle', type: 'address' },
    { name: 'chainId', type: 'uint256' },
  ],
} as const

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

interface ManualUpdateModalProps {
  isOpen: boolean
  onClose: () => void
  ticker: string
  onChainPrice: number
  offChainPrice: number
  oracleAddress: Address
  chainId: number
}

export function ManualUpdateModal({
  isOpen,
  onClose,
  ticker,
  onChainPrice,
  offChainPrice,
  oracleAddress,
  chainId,
}: ManualUpdateModalProps) {
  const { address, chain: currentChain } = useConnection()
  const { mutateAsync: switchChainAsync } = useSwitchChain()
  const { mutateAsync: signTypedDataAsync } = useSignTypedData()
  const { mutateAsync: writeContractAsync } = useWriteContract()
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Get current nonce from contract, forcing the correct chainId
  const {
    data: nonce,
    isLoading: isNonceLoading,
    error: nonceError,
    refetch: refetchNonce,
  } = useReadContract({
    address: oracleAddress,
    abi: RWA_ORACLE_ABI,
    functionName: 'nonce',
    chainId,
  })

  if (!isOpen) return null

  const delta = ((offChainPrice - onChainPrice) / onChainPrice) * 100

  const handleSignAndPush = async () => {
    if (!address) {
      toast.error('Please connect your wallet first')
      return
    }

    if (nonce === undefined) {
      toast.error('Oracle nonce is not loaded')
      return
    }

    setIsSubmitting(true)
    try {
      // 1. Ensure correct chain
      if (currentChain?.id !== chainId) {
        toast.info(`Switching to the correct network...`)
        await switchChainAsync({ chainId })
      }

      const price = BigInt(Math.round(offChainPrice * 10 ** 8))
      const timestamp = BigInt(Math.floor(Date.now() / 1000))

      // 2. EIP-712: sign typed data so wallet shows price, timestamp, nonce, etc.
      toast.info('Step 1/2: Sign the price data in your wallet...')

      const signature = await signTypedDataAsync({
        domain: {
          name: 'RwaOracle',
          version: '1',
          chainId,
          verifyingContract: oracleAddress,
        },
        types: PRICE_UPDATE_TYPES,
        primaryType: 'PriceUpdate',
        message: {
          price,
          timestamp,
          nonce: nonce as bigint,
          oracle: oracleAddress,
          chainId: BigInt(chainId),
        },
      })

      // 3. Submit Transaction
      toast.info('Step 2/2: Confirm the transaction in your wallet...')

      const hash = await writeContractAsync({
        address: oracleAddress,
        abi: RWA_ORACLE_ABI,
        functionName: 'updatePrice',
        args: [price, timestamp, [signature as Hex]],
      })

      toast.success('Update broadcasted successfully!')
      console.log('Transaction Hash:', hash)

      // Delay closing to let user see success
      setTimeout(() => {
        onClose()
        refetchNonce()
      }, 2000)
    } catch (error: unknown) {
      console.error('Manual update failed:', error)
      const errorMsg =
        error instanceof Error
          ? (error as { shortMessage?: string }).shortMessage || error.message
          : 'Unknown error'
      toast.error(`Update failed: ${errorMsg}`)
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-background-dark/80 backdrop-blur-sm transition-opacity"
        onClick={onClose}
      ></div>

      {/* Modal */}
      <div className="relative z-50 w-full max-w-2xl overflow-hidden rounded-xl border border-primary/30 bg-[#0f1623]/80 shadow-2xl backdrop-blur-xl animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-primary/10 bg-primary/5 px-6 py-5">
          <div>
            <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight text-white">
              <span className="material-icons-round text-primary text-xl">bolt</span>
              Trigger Manual Price Update
            </h2>
            <p className="text-sm font-medium text-slate-400">
              Asset: <span className="text-primary">{ticker}</span>
            </p>
          </div>
          <button onClick={onClose} className="text-slate-500 hover:text-white transition-colors">
            <span className="material-icons-round">close</span>
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* Price Comparison */}
          <div className="grid grid-cols-3 gap-4">
            <div className="bg-slate-900/50 p-4 rounded-lg border border-slate-800">
              <p className="text-[10px] uppercase tracking-wider text-slate-500 font-bold mb-1">
                On-Chain
              </p>
              <p className="text-lg font-mono font-semibold text-white">
                ${onChainPrice.toFixed(4)}
              </p>
            </div>
            <div className="bg-slate-900/50 p-4 rounded-lg border border-slate-800">
              <p className="text-[10px] uppercase tracking-wider text-slate-500 font-bold mb-1">
                Off-Chain
              </p>
              <p className="text-lg font-mono font-semibold text-primary">
                ${offChainPrice.toFixed(4)}
              </p>
            </div>
            <div className="bg-primary/10 p-4 rounded-lg border border-primary/20 flex flex-col justify-center items-center text-center">
              <p className="text-[10px] uppercase tracking-wider text-primary font-bold mb-1">
                Variance
              </p>
              <div
                className={cn(
                  'flex items-center gap-1 font-bold text-lg',
                  delta >= 0 ? 'text-emerald-400' : 'text-rose-400',
                )}
              >
                <span className="material-icons-round text-sm">
                  {delta >= 0 ? 'trending_up' : 'trending_down'}
                </span>
                {delta.toFixed(4)}%
              </div>
            </div>
          </div>

          {/* Technical Log */}
          <div className="space-y-2">
            <div className="flex justify-between items-center px-1">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-400">
                Signing Payload (Nonce: {nonce?.toString() || '...'})
              </label>
              <button
                onClick={() =>
                  navigator.clipboard.writeText(
                    JSON.stringify({
                      ticker,
                      oracle: oracleAddress,
                      newPrice: Math.round(offChainPrice * 10 ** 8),
                      timestamp: Math.floor(Date.now() / 1000),
                      nonce: nonce?.toString(),
                      chainId,
                    }),
                  )
                }
                className="text-[10px] text-primary hover:underline font-bold uppercase"
              >
                Copy JSON
              </button>
            </div>
            <div className="bg-black/40 border border-slate-800 rounded-lg p-4 font-mono text-[11px] leading-relaxed text-slate-400 h-32 overflow-y-auto custom-scrollbar">
              <pre>
                {JSON.stringify(
                  {
                    ticker,
                    oracle: oracleAddress,
                    newPrice: Math.round(offChainPrice * 10 ** 8),
                    timestamp: Math.floor(Date.now() / 1000),
                    nonce: nonce?.toString(),
                    chainId,
                  },
                  null,
                  2,
                )}
              </pre>
            </div>
          </div>

          {/* Action Button */}
          <div className="pt-2 space-y-4">
            {nonceError && (
              <p className="text-center text-rose-400 text-xs font-bold">
                Error loading oracle nonce. Is the contract deployed on this network?
              </p>
            )}
            <button
              onClick={handleSignAndPush}
              disabled={isSubmitting || nonce === undefined}
              className="w-full bg-primary hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed text-white font-bold py-4 rounded-xl flex items-center justify-center gap-3 shadow-[0_0_15px_rgba(31,104,249,0.4)] uppercase tracking-widest text-sm transition-all"
            >
              {isSubmitting || isNonceLoading ? (
                <span className="material-icons-round animate-spin">refresh</span>
              ) : (
                <span className="material-icons-round">draw</span>
              )}
              {isSubmitting
                ? 'Processing...'
                : isNonceLoading
                  ? 'Loading Nonce...'
                  : 'Sign & Push Update'}
            </button>
            <button
              onClick={onClose}
              className="w-full text-slate-500 hover:text-slate-300 font-semibold py-2 text-xs uppercase tracking-widest transition-colors text-center"
            >
              Cancel & Discard
            </button>
          </div>
        </div>

        {/* Footer Status */}
        <div className="bg-primary/5 px-6 py-3 border-t border-primary/10 flex items-center justify-between text-[10px] font-medium text-slate-500">
          <div className="flex items-center gap-4">
            <span className="flex items-center gap-1">
              <span className="material-icons-round text-[12px]">security</span> Multi-Sig Required:
              1/1
            </span>
            <span className="flex items-center gap-1">
              <span className="material-icons-round text-[12px]">speed</span> Est. Gas: 0.0002 ETH
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}
