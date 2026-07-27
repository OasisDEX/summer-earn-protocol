'use client'

import { useState } from 'react'
import { Address } from 'viem'

import { useArkManagement } from '../hooks/useArkManagement'
import type { ChainId } from '../types'
import { Button, helpTextBase, inputBase, labelBase } from './ui'

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
      <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
        <label className={labelBase}>Deposit Cap ({assetSymbol})</label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.depositCap}
            onChange={(e) => handleInputChange('depositCap', e.target.value)}
            placeholder="0.0"
            className={`flex-1 ${inputBase}`}
          />
          <Button
            variant="primary"
            onClick={handleSetDepositCap}
            disabled={
              !formData.depositCap ||
              isOperationPending(`setArkDepositCap_${arkAddress}`) ||
              isLoading
            }
          >
            {isOperationPending(`setArkDepositCap_${arkAddress}`) ? 'Setting…' : 'Set'}
          </Button>
        </div>
      </div>

      {/* Max Deposit Percentage of TVL */}
      <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
        <label className={labelBase}>Max Deposit Percentage of TVL (%)</label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.maxDepositPercentage}
            onChange={(e) => handleInputChange('maxDepositPercentage', e.target.value)}
            placeholder="10.0"
            min="0"
            max="100"
            step="0.01"
            className={`flex-1 ${inputBase}`}
          />
          <Button
            variant="primary"
            onClick={handleSetMaxDepositPercentage}
            disabled={
              !formData.maxDepositPercentage ||
              isOperationPending(`setArkMaxDepositPercentageOfTVL_${arkAddress}`) ||
              isLoading
            }
          >
            {isOperationPending(`setArkMaxDepositPercentageOfTVL_${arkAddress}`)
              ? 'Setting…'
              : 'Set'}
          </Button>
        </div>
        <p className={helpTextBase}>
          Enter percentage (e.g., 10 for 10%). Will be converted to WAD format (10% = 10e18).
        </p>
      </div>

      {/* Max Rebalance Outflow */}
      <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
        <label className={labelBase}>Max Rebalance Outflow ({assetSymbol})</label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.maxRebalanceOutflow}
            onChange={(e) => handleInputChange('maxRebalanceOutflow', e.target.value)}
            placeholder="0.0"
            className={`flex-1 ${inputBase}`}
          />
          <Button
            variant="primary"
            onClick={handleSetMaxRebalanceOutflow}
            disabled={
              !formData.maxRebalanceOutflow ||
              isOperationPending(`setArkMaxRebalanceOutflow_${arkAddress}`) ||
              isLoading
            }
          >
            {isOperationPending(`setArkMaxRebalanceOutflow_${arkAddress}`) ? 'Setting…' : 'Set'}
          </Button>
        </div>
      </div>

      {/* Max Rebalance Inflow */}
      <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
        <label className={labelBase}>Max Rebalance Inflow ({assetSymbol})</label>
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.maxRebalanceInflow}
            onChange={(e) => handleInputChange('maxRebalanceInflow', e.target.value)}
            placeholder="0.0"
            className={`flex-1 ${inputBase}`}
          />
          <Button
            variant="primary"
            onClick={handleSetMaxRebalanceInflow}
            disabled={
              !formData.maxRebalanceInflow ||
              isOperationPending(`setArkMaxRebalanceInflow_${arkAddress}`) ||
              isLoading
            }
          >
            {isOperationPending(`setArkMaxRebalanceInflow_${arkAddress}`) ? 'Setting…' : 'Set'}
          </Button>
        </div>
      </div>

      {/* Remove Ark - Danger Zone */}
      <div className="bg-error/10 border border-error/20 p-3 rounded-lg">
        <h4 className="text-sm font-medium text-error mb-2">Danger Zone</h4>
        <p className="text-xs text-error/80 mb-3">
          Removing an ark will permanently remove it from the fleet. This action cannot be undone.
        </p>
        <Button
          variant="danger"
          onClick={handleRemoveArk}
          disabled={isOperationPending(`removeArk_${arkAddress}`) || isLoading}
        >
          {isOperationPending(`removeArk_${arkAddress}`) ? 'Removing…' : 'Remove Ark'}
        </Button>
      </div>

      {/* Error Display */}
      {(writeError || confirmError) && (
        <div className="bg-error/10 border border-error/20 p-3 rounded-lg">
          <p className="text-sm text-error">
            Error: {writeError?.message || confirmError?.message}
          </p>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="bg-info/10 border border-info/20 p-3 rounded-lg">
          <p className="text-sm text-info">
            {isWritePending ? 'Preparing transaction…' : 'Confirming transaction…'}
          </p>
        </div>
      )}
    </div>
  )
}
