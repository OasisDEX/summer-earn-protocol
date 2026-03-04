'use client'

import { useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { erc20Abi } from 'viem'

interface VaultInteractionFormProps {
  title: string
  description: string
  vaultAddress: `0x${string}`
  vaultAbi: any
  underlyingAsset: `0x${string}`
  sharesAsset: `0x${string}`
  // For input vault: deposits underlying, returns shares
  // For output vault: deposits shares, returns underlying
  depositAsset: `0x${string}`
  receiveAsset: `0x${string}`
  decimals: number
  symbol: string
  receiptSymbol: string
}

export function VaultInteractionForm({
  title,
  description,
  vaultAddress,
  vaultAbi,
  depositAsset,
  receiveAsset,
  decimals,
  symbol,
  receiptSymbol,
}: VaultInteractionFormProps) {
  const { address } = useAccount()
  const [amount, setAmount] = useState('')
  const [receiptId, setReceiptId] = useState('')

  // Read current round
  const { data: currentRound } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'getCurrentRound',
  })

  // Read user balance of the asset to deposit
  const { data: balance } = useReadContract({
    address: depositAsset,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  }) as { data: bigint | undefined }

  // Read user receipts balance for current round
  const { data: receiptsBalance } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'balanceOf',
    args: address && currentRound !== undefined ? [address, currentRound as bigint] : undefined,
    query: {
      enabled: !!address && currentRound !== undefined,
    },
  }) as { data: bigint | undefined }

  // Read exchange asset
  const { data: exchangeAsset } = useReadContract({
    address: vaultAddress,
    abi: vaultAbi,
    functionName: 'exchangeAsset',
  }) as { data: `0x${string}` | undefined }

  const { writeContractAsync, isPending } = useWriteContract()

  const handleDeposit = async () => {
    if (!amount || !address) return
    const parsedAmount = parseUnits(amount, decimals)
    try {
      // 1. Approve
      await writeContractAsync({
        address: depositAsset,
        abi: erc20Abi,
        functionName: 'approve',
        args: [vaultAddress, parsedAmount],
      } as any)
      // 2. Deposit
      await (writeContractAsync as any)({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'deposit',
        args: [parsedAmount, address],
      })
      setAmount('')
    } catch (e) {
      console.error(e)
    }
  }

  const handleExchange = async () => {
    if (!receiptId || !address) return
    try {
      const balanceToConvert = await (writeContractAsync as any)({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'redeemExchangeAsset',
        args: [BigInt(receiptId), 0n, address, address],
      })
    } catch (e) {
      console.error(e)
    }
  }

  const handleNextRound = async () => {
    try {
      await (writeContractAsync as any)({
        address: vaultAddress,
        abi: vaultAbi,
        functionName: 'nextRound',
      })
    } catch (e) {
      console.error(e)
    }
  }

  return (
    <div className="bg-charcoal-800/60 p-6 rounded-2xl border border-white/5 backdrop-blur-xl shadow-2xl hover:border-white/10 transition-all duration-300">
      <h2 className="text-2xl font-bold bg-gradient-to-r from-blue-400 to-indigo-400 bg-clip-text text-transparent mb-2">
        {title}
      </h2>
      <p className="text-gray-400 text-sm mb-6">{description}</p>

      <div className="space-y-4 mb-8">
        <div className="flex justify-between items-center bg-gray-900/50 p-4 rounded-xl border border-white/5">
          <span className="text-gray-400">Current Round</span>
          <span className="font-mono text-white text-lg font-medium">
            {currentRound !== undefined ? currentRound.toString() : 'Loading...'}
          </span>
        </div>
        <div className="flex justify-between items-center bg-gray-900/50 p-4 rounded-xl border border-white/5">
          <span className="text-gray-400">Your Receipts (Current Round)</span>
          <span className="font-mono text-white text-lg font-medium">
            {receiptsBalance !== undefined ? formatUnits(receiptsBalance as bigint, decimals) : '0'}{' '}
            {receiptSymbol}
          </span>
        </div>
      </div>

      <div className="space-y-6">
        <div className="space-y-3">
          <h3 className="text-sm font-semibold text-gray-300 uppercase tracking-wider">
            Deposit for Next Round
          </h3>
          <div className="flex gap-3">
            <input
              type="text"
              placeholder={`Amount in ${symbol}`}
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="flex-1 bg-gray-900 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all"
            />
            <button
              onClick={handleDeposit}
              disabled={isPending || !amount}
              className="bg-blue-500 hover:bg-blue-400 text-white font-medium px-6 py-3 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95"
            >
              Deposit
            </button>
          </div>
          <div className="text-xs text-gray-500 text-right">
            Balance: {balance !== undefined ? formatUnits(balance as bigint, decimals) : '0'}{' '}
            {symbol}
          </div>
        </div>

        <div className="h-px bg-white/5 w-full my-6"></div>

        <div className="space-y-3">
          <h3 className="text-sm font-semibold text-gray-300 uppercase tracking-wider">
            Exchange Past Receipts
          </h3>
          <div className="flex gap-3">
            <input
              type="number"
              placeholder="Round ID to Exchange"
              value={receiptId}
              onChange={(e) => setReceiptId(e.target.value)}
              className="flex-1 bg-gray-900 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/50 transition-all"
            />
            <button
              onClick={handleExchange}
              disabled={isPending || !receiptId}
              className="bg-indigo-500 hover:bg-indigo-400 text-white font-medium px-6 py-3 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95"
            >
              Exchange
            </button>
          </div>
        </div>

        <div className="h-px bg-white/5 w-full my-6"></div>

        {/* Keeper & ABI Data Section */}
        <div className="space-y-4 bg-gray-900/40 p-5 rounded-xl border border-blue-500/20">
          <h3 className="text-sm font-semibold text-blue-400 uppercase tracking-wider flex items-center justify-between">
            Keeper Actions & Protocol State
          </h3>

          {exchangeAsset && (
            <div className="text-xs text-gray-400 break-all mb-4">
              <span className="text-gray-500 block mb-1">Exchange Asset Contract:</span>
              <code className="text-blue-300 font-mono bg-blue-900/20 px-2 py-1 rounded">
                {exchangeAsset}
              </code>
            </div>
          )}

          <div className="flex justify-between items-center pt-2 border-t border-white/5">
            <span className="text-sm text-gray-400">
              Advance to Round {currentRound !== undefined ? Number(currentRound) + 1 : '...'}
            </span>
            <button
              onClick={handleNextRound}
              disabled={isPending}
              className="bg-red-500/20 text-red-400 hover:bg-red-500/30 hover:text-red-300 border border-red-500/30 font-medium px-4 py-2 rounded-lg text-sm transition-all disabled:opacity-50 disabled:cursor-not-allowed transform active:scale-95"
            >
              Execute nextRound()
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
