'use client'

import { useState, useEffect } from 'react'
import { type Address, parseUnits, formatUnits } from 'viem'
import { useWriteContract, useWaitForTransactionReceipt, useReadContract, useAccount } from 'wagmi'
import { TEST_YIELD_FACTORY_ABI, TEST_YIELD_TOKEN_ABI, ERC20_ABI } from '../config/abis'
import { toast } from 'sonner'

interface YieldActionModalProps {
  isOpen: boolean
  onClose: () => void
  action: 'deposit' | 'withdraw'
  ticker: string
  factoryAddress: Address
  tokenAddress?: Address
}

export function YieldActionModal({
  isOpen,
  onClose,
  action,
  ticker,
  factoryAddress,
  tokenAddress,
}: YieldActionModalProps) {
  const { address: connectedAddress } = useAccount()
  const [userAddress, setUserAddress] = useState('')
  const [amount, setAmount] = useState('')

  // Auto-fill connected wallet when modal opens
  useEffect(() => {
    if (isOpen && connectedAddress) {
      setUserAddress(connectedAddress)
    }
    if (isOpen) {
      setAmount('')
    }
  }, [isOpen, connectedAddress])

  const { writeContract, data: hash, isPending: isWritePending, reset } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  // Get USDC and pocket from token
  const { data: usdcAddress } = useReadContract({
    address: tokenAddress,
    abi: TEST_YIELD_TOKEN_ABI,
    functionName: 'usdc',
    query: { enabled: !!tokenAddress },
  })
  const { data: pocketAddress } = useReadContract({
    address: tokenAddress,
    abi: TEST_YIELD_TOKEN_ABI,
    functionName: 'pocket',
    query: { enabled: !!tokenAddress },
  })

  // Contract's USDC: main contract (pending deposits) + pocket
  const { data: contractUsdcBal } = useReadContract({
    address: usdcAddress as Address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [tokenAddress!],
    query: { enabled: !!usdcAddress && !!tokenAddress },
  })
  const { data: pocketUsdcBal } = useReadContract({
    address: usdcAddress as Address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [pocketAddress!],
    query: { enabled: !!usdcAddress && !!pocketAddress },
  })
  // Contract's share balance (shares deposited by users for withdrawal)
  const { data: contractShareBalance } = useReadContract({
    address: tokenAddress,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [tokenAddress!],
    query: { enabled: !!tokenAddress },
  })

  const handleMax = () => {
    if (action === 'withdraw' && contractShareBalance) {
      setAmount(formatUnits(contractShareBalance, 18))
    } else if (action === 'deposit' && contractUsdcBal) {
      setAmount(formatUnits(contractUsdcBal, 6))
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!userAddress || !amount) return

    try {
      const decimals = action === 'deposit' ? 6 : 18
      const parsedAmount = parseUnits(amount, decimals)

      if (action === 'deposit') {
        writeContract({
          address: factoryAddress,
          abi: TEST_YIELD_FACTORY_ABI,
          functionName: 'processDeposit',
          args: [ticker, userAddress as Address, parsedAmount],
        })
      } else {
        writeContract({
          address: factoryAddress,
          abi: TEST_YIELD_FACTORY_ABI,
          functionName: 'processWithdraw',
          args: [ticker, userAddress as Address, parsedAmount],
        })
      }
    } catch (err: unknown) {
      toast.error((err as Error).message ?? 'Transaction failed')
    }
  }

  // Effect to handle success and close
  if (isSuccess) {
    toast.success(`${action === 'deposit' ? 'Deposit' : 'Withdrawal'} processed successfully!`)
    setTimeout(() => {
      reset()
      onClose()
    }, 2000)
  }

  if (!isOpen) return null

  const isPending = isWritePending || isConfirming

  const hasMaxBalance =
    action === 'withdraw'
      ? contractShareBalance !== undefined && contractShareBalance > BigInt(0)
      : contractUsdcBal !== undefined && contractUsdcBal > BigInt(0)

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 w-full max-w-md shadow-2xl animate-in fade-in zoom-in-95 duration-200">
        <h2 className="text-xl font-bold mb-4 capitalize">
          {action} for {ticker}
        </h2>

        {tokenAddress && (
          <div className="mb-4 space-y-2">
            <div className="p-3 bg-black/50 rounded-lg border border-gray-800">
              <span className="text-xs text-gray-400">USDC in contract: </span>
              <span className="font-mono font-bold text-green-400">
                {contractUsdcBal !== undefined ? formatUnits(contractUsdcBal, 6) : '-'}
              </span>
              <span className="text-xs text-gray-500 ml-1">(main) / </span>
              <span className="font-mono text-green-400">
                {pocketUsdcBal !== undefined ? formatUnits(pocketUsdcBal, 6) : '-'}
              </span>
              <span className="text-xs text-gray-500"> (pocket)</span>
            </div>
            <div className="p-3 bg-black/50 rounded-lg border border-gray-800">
              <span className="text-xs text-gray-400">Shares in contract: </span>
              <span className="font-mono font-bold text-blue-400">
                {contractShareBalance !== undefined ? formatUnits(contractShareBalance, 18) : '-'}
              </span>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm text-gray-400 mb-1">
              User Address (who receives shares / USDC)
            </label>
            <input
              type="text"
              placeholder="0x..."
              value={userAddress}
              onChange={(e) => setUserAddress(e.target.value)}
              className="w-full bg-black border border-gray-700 rounded p-2 font-mono text-sm focus:border-blue-500 outline-none"
              disabled={isPending}
            />
          </div>

          <div>
            <div className="flex justify-between items-center mb-1">
              <label className="block text-sm text-gray-400">
                Amount ({action === 'deposit' ? 'USDC' : 'Shares'})
              </label>
              {hasMaxBalance && (
                <button
                  type="button"
                  onClick={handleMax}
                  className="text-xs text-blue-400 hover:text-blue-300 font-medium"
                >
                  MAX
                </button>
              )}
            </div>
            <input
              type="number"
              placeholder="0.00"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="w-full bg-black border border-gray-700 rounded p-2 font-mono text-sm focus:border-blue-500 outline-none"
              disabled={isPending}
            />
          </div>

          <div className="flex gap-3 mt-6">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 bg-gray-800 hover:bg-gray-700 rounded text-sm font-medium transition-colors"
              disabled={isPending}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded text-sm font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              disabled={isPending || !userAddress || !amount}
            >
              {isPending && (
                <span className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
              )}
              {isPending ? 'Processing...' : 'Confirm'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
