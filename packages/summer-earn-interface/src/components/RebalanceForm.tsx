'use client'

import { useState } from 'react'

import type { ArkInfo, RebalanceData } from '../types'
import { formatDecimalOutput } from '../utils/decimals'
import { AmountInput } from './AmountInput'

interface RebalanceRow {
  id: string
  fromArk: `0x${string}`
  toArk: `0x${string}`
  amount: string
  parsedAmount: bigint
  boardData: string
  disembarkData: string
}

const createEmptyRow = (): RebalanceRow => ({
  id: crypto.randomUUID(),
  fromArk: '0x',
  toArk: '0x',
  amount: '',
  parsedAmount: BigInt(0),
  boardData: '0x',
  disembarkData: '0x',
})

interface RebalanceFormProps {
  arks: ArkInfo[]
  assetSymbol: string
  assetDecimals: number
  onRebalance: (data: RebalanceData[]) => void
  isLoading: boolean
}

export function RebalanceForm({
  arks,
  assetSymbol,
  assetDecimals,
  onRebalance,
  isLoading,
}: RebalanceFormProps) {
  const [rows, setRows] = useState<RebalanceRow[]>(() => [createEmptyRow()])

  const addRow = () => {
    setRows((prev) => [...prev, createEmptyRow()])
  }

  const removeRow = (id: string) => {
    setRows((prev) => {
      if (prev.length <= 1) return prev
      return prev.filter((r) => r.id !== id)
    })
  }

  const updateRow = (id: string, updates: Partial<RebalanceRow>) => {
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...updates } : r)))
  }

  const handleSubmit = () => {
    const validRows = rows.filter(
      (r) =>
        r.fromArk &&
        r.toArk &&
        r.parsedAmount > BigInt(0) &&
        r.fromArk !== '0x' &&
        r.toArk !== '0x' &&
        r.fromArk !== r.toArk,
    )
    if (validRows.length === 0) return

    const rebalanceData: RebalanceData[] = validRows.map((r) => ({
      fromArk: r.fromArk,
      toArk: r.toArk,
      amount: r.parsedAmount,
      boardData: r.boardData as `0x${string}`,
      disembarkData: r.disembarkData as `0x${string}`,
    }))

    onRebalance(rebalanceData)
  }

  const hasValidRows = rows.some(
    (r) =>
      r.fromArk !== '0x' && r.toArk !== '0x' && r.fromArk !== r.toArk && r.parsedAmount > BigInt(0),
  )
  const canSubmit = hasValidRows && !isLoading

  return (
    <div className="bg-gray-900 p-6 rounded-lg">
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-xl font-semibold text-white">Rebalance Assets</h3>
        <button
          type="button"
          onClick={addRow}
          className="px-3 py-1.5 text-sm bg-blue-600 hover:bg-blue-700 text-white rounded-md transition-colors font-medium"
        >
          + Add Row
        </button>
      </div>

      <div className="space-y-6">
        {rows.map((row, index) => (
          <RebalanceRowForm
            key={row.id}
            row={row}
            index={index}
            arks={arks}
            assetSymbol={assetSymbol}
            assetDecimals={assetDecimals}
            onUpdate={(updates) => updateRow(row.id, updates)}
            onRemove={rows.length > 1 ? () => removeRow(row.id) : undefined}
          />
        ))}

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

interface RebalanceRowFormProps {
  row: RebalanceRow
  index: number
  arks: ArkInfo[]
  assetSymbol: string
  assetDecimals: number
  onUpdate: (updates: Partial<RebalanceRow>) => void
  onRemove?: () => void
}

function RebalanceRowForm({
  row,
  index,
  arks,
  assetSymbol,
  assetDecimals,
  onUpdate,
  onRemove,
}: RebalanceRowFormProps) {
  const selectedFromArk = arks.find((ark) => ark.address === row.fromArk)

  return (
    <div className="p-4 bg-gray-800 rounded-lg border border-gray-700 space-y-4">
      <div className="flex justify-between items-center">
        <span className="text-sm font-medium text-gray-400">Rebalance #{index + 1}</span>
        {onRemove && (
          <button
            type="button"
            onClick={onRemove}
            className="text-red-400 hover:text-red-300 text-sm font-medium"
          >
            Remove
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* From Ark */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">From Ark</label>
          <select
            value={row.fromArk}
            onChange={(e) => onUpdate({ fromArk: e.target.value as `0x${string}` })}
            className="w-full p-3 bg-gray-700 border border-gray-600 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
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
        </div>

        {/* To Ark */}
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">To Ark</label>
          <select
            value={row.toArk}
            onChange={(e) => onUpdate({ toArk: e.target.value as `0x${string}` })}
            className="w-full p-3 bg-gray-700 border border-gray-600 rounded-lg text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="0x">Select destination ark...</option>
            {arks
              .filter((ark) => ark.address !== row.fromArk)
              .map((ark) => (
                <option key={`to-${ark.address}`} value={ark.address}>
                  {ark.name}
                  {ark.isBufferArk ? ' (Buffer)' : ''} - {ark.address.slice(0, 6)}...
                  {ark.address.slice(-4)}
                </option>
              ))}
          </select>
        </div>
      </div>

      {selectedFromArk && (
        <div className="p-3 bg-gray-700/50 rounded-lg text-sm text-gray-300">
          <div className="flex items-center gap-2 mb-1">
            <span className="font-medium">{selectedFromArk.name}</span>
            {selectedFromArk.isBufferArk && (
              <span className="px-2 py-0.5 bg-blue-600 text-blue-100 text-xs rounded-full">
                Buffer Ark
              </span>
            )}
          </div>
          <div>
            Withdrawable:{' '}
            {formatDecimalOutput(selectedFromArk.withdrawableTotalAssets, assetDecimals)}{' '}
            {assetSymbol}
          </div>
        </div>
      )}

      <AmountInput
        value={row.amount}
        onChange={(value, parsed) => {
          onUpdate({ amount: value, parsedAmount: parsed })
        }}
        symbol={assetSymbol}
        decimals={assetDecimals}
        balance={selectedFromArk?.withdrawableTotalAssets}
        showMaxButton={true}
        showMaxUintButton={true}
        label="Amount to Rebalance"
        placeholder={`Enter amount in ${assetSymbol}`}
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Board Data (Optional)
          </label>
          <input
            type="text"
            value={row.boardData}
            onChange={(e) => onUpdate({ boardData: e.target.value })}
            placeholder="0x"
            className="w-full p-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm font-mono focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-300 mb-2">
            Disembark Data (Optional)
          </label>
          <input
            type="text"
            value={row.disembarkData}
            onChange={(e) => onUpdate({ disembarkData: e.target.value })}
            placeholder="0x"
            className="w-full p-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm font-mono focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      </div>
    </div>
  )
}
