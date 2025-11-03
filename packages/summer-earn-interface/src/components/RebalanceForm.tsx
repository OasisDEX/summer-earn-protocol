'use client'

import { useState } from 'react'

import type { ArkInfo } from '../types'
import { AmountInput } from './AmountInput'

interface RebalanceFormProps {
  arks: ArkInfo[]
  assetSymbol: string
  assetDecimals: number
  onRebalance: (data: {
    fromArk: `0x${string}`
    toArk: `0x${string}`
    amount: bigint
    boardData: `0x${string}`
    disembarkData: `0x${string}`
  }) => void
  isLoading: boolean
}

export function RebalanceForm({
  arks,
  assetSymbol,
  assetDecimals,
  onRebalance,
  isLoading,
}: RebalanceFormProps) {
  const [fromArk, setFromArk] = useState<`0x${string}`>('0x')
  const [toArk, setToArk] = useState<`0x${string}`>('0x')
  const [amount, setAmount] = useState('')
  const [parsedAmount, setParsedAmount] = useState<bigint>(BigInt(0))
  const [boardData, setBoardData] = useState('0x')
  const [disembarkData, setDisembarkData] = useState('0x')

  const selectedFromArk = arks.find((ark) => ark.address === fromArk)

  const handleSubmit = () => {
    if (!fromArk || !toArk || !parsedAmount || fromArk === '0x' || toArk === '0x') return

    onRebalance({
      fromArk,
      toArk,
      amount: parsedAmount,
      boardData: boardData as `0x${string}`,
      disembarkData: disembarkData as `0x${string}`,
    })
  }

  const canSubmit = fromArk !== '0x' && toArk !== '0x' && parsedAmount > BigInt(0) && !isLoading

  return (
    <div className="bg-gray-900 p-6 rounded-lg">
      <h3 className="text-xl font-semibold text-white mb-6">Rebalance Assets</h3>

      <div className="space-y-6">
        {/* From Ark Selection */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">From Ark</label>
          <select
            value={fromArk}
            onChange={(e) => setFromArk(e.target.value as `0x${string}`)}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="0x">Select source ark...</option>
            {arks.map((ark) => (
              <option key={`from-${ark.address}`} value={ark.address}>
                {ark.name}
                {ark.isBufferArk ? ' (Buffer)' : ''} - {ark.address.slice(0, 6)}...
                {ark.address.slice(-4)}
              </option>
            ))}
          </select>
          {selectedFromArk && (
            <div className="mt-2 p-3 bg-gray-800 rounded-lg">
              <div className="text-sm text-gray-300">
                <div className="flex items-center gap-2 mb-1">
                  <span className="font-medium">{selectedFromArk.name}</span>
                  {selectedFromArk.isBufferArk && (
                    <span className="px-2 py-1 bg-blue-600 text-blue-100 text-xs rounded-full">
                      Buffer Ark
                    </span>
                  )}
                </div>
                <div>
                  Total Assets:{' '}
                  {(Number(selectedFromArk.totalAssets) / Math.pow(10, assetDecimals)).toFixed(4)}{' '}
                  {assetSymbol}
                </div>
                <div>
                  Withdrawable:{' '}
                  {(
                    Number(selectedFromArk.withdrawableTotalAssets) / Math.pow(10, assetDecimals)
                  ).toFixed(4)}{' '}
                  {assetSymbol}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* To Ark Selection */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">To Ark</label>
          <select
            value={toArk}
            onChange={(e) => setToArk(e.target.value as `0x${string}`)}
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="0x">Select destination ark...</option>
            {arks
              .filter((ark) => ark.address !== fromArk)
              .map((ark) => (
                <option key={`to-${ark.address}`} value={ark.address}>
                  {ark.name}
                  {ark.isBufferArk ? ' (Buffer)' : ''} - {ark.address.slice(0, 6)}...
                  {ark.address.slice(-4)}
                </option>
              ))}
          </select>
        </div>

        {/* Amount Input */}
        <AmountInput
          value={amount}
          onChange={(value, parsed) => {
            setAmount(value)
            setParsedAmount(parsed)
          }}
          symbol={assetSymbol}
          decimals={assetDecimals}
          balance={selectedFromArk?.withdrawableTotalAssets}
          showMaxButton={true}
          showMaxUintButton={true}
          label="Amount to Rebalance"
          placeholder={`Enter amount in ${assetSymbol}`}
        />

        {/* Board Data */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Board Data (Optional)
          </label>
          <input
            type="text"
            value={boardData}
            onChange={(e) => setBoardData(e.target.value)}
            placeholder="0x"
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono"
          />
        </div>

        {/* Disembark Data */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Disembark Data (Optional)
          </label>
          <input
            type="text"
            value={disembarkData}
            onChange={(e) => setDisembarkData(e.target.value)}
            placeholder="0x"
            className="w-full p-3 bg-gray-800 border border-gray-700 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent font-mono"
          />
        </div>

        {/* Submit Button */}
        <button
          onClick={handleSubmit}
          disabled={!canSubmit}
          className={`w-full p-3 rounded-lg font-semibold transition-colors ${
            canSubmit
              ? 'bg-green-600 hover:bg-green-700 text-white'
              : 'bg-gray-600 text-gray-400 cursor-not-allowed'
          }`}
        >
          {isLoading ? 'Rebalancing...' : 'Execute Rebalance'}
        </button>
      </div>
    </div>
  )
}
