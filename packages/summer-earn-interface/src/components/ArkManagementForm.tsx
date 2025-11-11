'use client'

import { useState } from 'react'
import { Address } from 'viem'

import { useArkManagement } from '../hooks/useArkManagement'
import type { ChainId } from '../types'

interface ArkManagementFormProps {
  arkAddress: Address
  fleetAddress: Address
  chainId: ChainId
  assetDecimals: number
  assetSymbol: string
}

export function ArkManagementForm({
  arkAddress,
  fleetAddress,
  chainId,
  assetDecimals,
  assetSymbol,
}: ArkManagementFormProps) {
  const [formData, setFormData] = useState({
    depositCap: '',
    maxDepositPercentage: '',
    maxRebalanceOutflow: '',
    maxRebalanceInflow: '',
  })

  const {
    setArkDepositCap,
    setArkMaxDepositPercentageOfTVL,
    setArkMaxRebalanceOutflow,
    setArkMaxRebalanceInflow,
    removeArk,
    isOperationPending,
    isWritePending,
    isConfirming,
    writeError,
    confirmError,
  } = useArkManagement({ fleetAddress, chainId })

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }))
  }

  const handleSetDepositCap = async () => {
    if (!formData.depositCap) return
    await setArkDepositCap(arkAddress, formData.depositCap, assetDecimals)
  }

  const handleSetMaxDepositPercentage = async () => {
    if (!formData.maxDepositPercentage) return
    await setArkMaxDepositPercentageOfTVL(arkAddress, formData.maxDepositPercentage)
  }

  const handleSetMaxRebalanceOutflow = async () => {
    if (!formData.maxRebalanceOutflow) return
    await setArkMaxRebalanceOutflow(arkAddress, formData.maxRebalanceOutflow, assetDecimals)
  }

  const handleSetMaxRebalanceInflow = async () => {
    if (!formData.maxRebalanceInflow) return
    await setArkMaxRebalanceInflow(arkAddress, formData.maxRebalanceInflow, assetDecimals)
  }

  const handleRemoveArk = async () => {
    if (window.confirm('Are you sure you want to remove this ark? This action cannot be undone.')) {
      await removeArk(arkAddress)
    }
  }

  const isLoading = isWritePending || isConfirming

  return (
    <div className="space-y-4">
      {/* Deposit Cap */}
      <div className="bg-gray-200 p-3 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Deposit Cap ({assetSymbol})
        </label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.depositCap}
            onChange={(e) => handleInputChange('depositCap', e.target.value)}
            placeholder="0.0"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSetDepositCap}
            disabled={
              !formData.depositCap ||
              isOperationPending(`setArkDepositCap_${arkAddress}`) ||
              isLoading
            }
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isOperationPending(`setArkDepositCap_${arkAddress}`) ? 'Setting...' : 'Set'}
          </button>
        </div>
      </div>

      {/* Max Deposit Percentage of TVL */}
      <div className="bg-gray-200 p-3 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Max Deposit Percentage of TVL (%)
        </label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.maxDepositPercentage}
            onChange={(e) => handleInputChange('maxDepositPercentage', e.target.value)}
            placeholder="10.0"
            min="0"
            max="100"
            step="0.01"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSetMaxDepositPercentage}
            disabled={
              !formData.maxDepositPercentage ||
              isOperationPending(`setArkMaxDepositPercentageOfTVL_${arkAddress}`) ||
              isLoading
            }
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isOperationPending(`setArkMaxDepositPercentageOfTVL_${arkAddress}`)
              ? 'Setting...'
              : 'Set'}
          </button>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          Enter percentage (e.g., 10 for 10%). Will be converted to WAD format (10% = 10e18).
        </p>
      </div>

      {/* Max Rebalance Outflow */}
      <div className="bg-gray-200 p-3 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Max Rebalance Outflow ({assetSymbol})
        </label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.maxRebalanceOutflow}
            onChange={(e) => handleInputChange('maxRebalanceOutflow', e.target.value)}
            placeholder="0.0"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSetMaxRebalanceOutflow}
            disabled={
              !formData.maxRebalanceOutflow ||
              isOperationPending(`setArkMaxRebalanceOutflow_${arkAddress}`) ||
              isLoading
            }
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isOperationPending(`setArkMaxRebalanceOutflow_${arkAddress}`) ? 'Setting...' : 'Set'}
          </button>
        </div>
      </div>

      {/* Max Rebalance Inflow */}
      <div className="bg-gray-200 p-3 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Max Rebalance Inflow ({assetSymbol})
        </label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.maxRebalanceInflow}
            onChange={(e) => handleInputChange('maxRebalanceInflow', e.target.value)}
            placeholder="0.0"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSetMaxRebalanceInflow}
            disabled={
              !formData.maxRebalanceInflow ||
              isOperationPending(`setArkMaxRebalanceInflow_${arkAddress}`) ||
              isLoading
            }
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isOperationPending(`setArkMaxRebalanceInflow_${arkAddress}`) ? 'Setting...' : 'Set'}
          </button>
        </div>
      </div>

      {/* Remove Ark - Danger Zone */}
      <div className="bg-red-50 border border-red-200 p-3 rounded-md">
        <h4 className="text-sm font-medium text-red-800 mb-2">Danger Zone</h4>
        <p className="text-xs text-red-600 mb-3">
          Removing an ark will permanently remove it from the fleet. This action cannot be undone.
        </p>
        <button
          onClick={handleRemoveArk}
          disabled={isOperationPending(`removeArk_${arkAddress}`) || isLoading}
          className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isOperationPending(`removeArk_${arkAddress}`) ? 'Removing...' : 'Remove Ark'}
        </button>
      </div>

      {/* Error Display */}
      {(writeError || confirmError) && (
        <div className="bg-red-50 border border-red-200 p-3 rounded-md">
          <p className="text-sm text-red-600">
            Error: {writeError?.message || confirmError?.message}
          </p>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="bg-blue-50 border border-blue-200 p-3 rounded-md">
          <p className="text-sm text-blue-600">
            {isWritePending ? 'Preparing transaction...' : 'Confirming transaction...'}
          </p>
        </div>
      )}
    </div>
  )
}
