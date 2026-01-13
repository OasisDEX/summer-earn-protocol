'use client'

import { useState } from 'react'
import { Address } from 'viem'

import { useArkManagement } from '../hooks/useArkManagement'
import { useFleetManagement } from '../hooks/useFleetManagement'
import type { ArkInfo, ChainId, FleetCommanderInfo } from '../types'
import { formatDecimalOutput, formatPercentage } from '../utils/decimals'

interface FleetManagementFormProps {
  fleetAddress: Address
  chainId: ChainId
  assetDecimals: number
  assetSymbol: string
  fleetInfo: FleetCommanderInfo | null
  arks: ArkInfo[]
}

export function FleetManagementForm({
  fleetAddress,
  chainId,
  assetDecimals,
  assetSymbol,
  fleetInfo,
  arks,
}: FleetManagementFormProps) {
  const [formData, setFormData] = useState({
    minimumBufferBalance: '',
    fleetDepositCap: '',
    maxRebalanceOperations: '',
    newArkAddress: '',
  })

  const {
    setMinimumBufferBalance,
    setFleetDepositCap,
    setMaxRebalanceOperations,
    setFleetTokenTransferability,
    isOperationPending: isFleetOperationPending,
    isWritePending: isFleetWritePending,
    isConfirming: isFleetConfirming,
    writeError: fleetWriteError,
    confirmError: fleetConfirmError,
  } = useFleetManagement({ fleetAddress, chainId })

  const {
    addArk,
    isOperationPending: isArkOperationPending,
    isWritePending: isArkWritePending,
    isConfirming: isArkConfirming,
    writeError: arkWriteError,
    confirmError: arkConfirmError,
  } = useArkManagement({ fleetAddress, chainId })

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }))
  }

  const handleSetMinimumBufferBalance = async () => {
    if (!formData.minimumBufferBalance) return
    await setMinimumBufferBalance(formData.minimumBufferBalance, assetDecimals)
  }

  const handleSetFleetDepositCap = async () => {
    if (!formData.fleetDepositCap) return
    await setFleetDepositCap(formData.fleetDepositCap, assetDecimals)
  }

  const handleSetMaxRebalanceOperations = async () => {
    if (!formData.maxRebalanceOperations) return
    await setMaxRebalanceOperations(formData.maxRebalanceOperations)
  }

  const handleAddArk = async () => {
    if (!formData.newArkAddress) return
    await addArk(formData.newArkAddress)
    setFormData((prev) => ({ ...prev, newArkAddress: '' }))
  }

  const handleEnableTransfers = async () => {
    if (
      window.confirm(
        'Are you sure you want to enable fleet token transfers? This action cannot be undone.',
      )
    ) {
      await setFleetTokenTransferability()
    }
  }

  const isLoading = isFleetWritePending || isFleetConfirming || isArkWritePending || isArkConfirming
  const hasError = fleetWriteError || fleetConfirmError || arkWriteError || arkConfirmError

  return (
    <div className="space-y-6">
      <h3 className="text-lg font-semibold text-gray-800">Fleet Configuration</h3>

      {/* Minimum Buffer Balance */}
      <div className="bg-gray-100 p-4 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Minimum Buffer Balance ({assetSymbol})
        </label>
        {fleetInfo && (
          <p className="text-sm text-gray-600 mb-2">
            Current: {formatDecimalOutput(fleetInfo.minimumBufferBalance, assetDecimals)}{' '}
            {assetSymbol}
          </p>
        )}
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.minimumBufferBalance}
            onChange={(e) => handleInputChange('minimumBufferBalance', e.target.value)}
            placeholder="0.0"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSetMinimumBufferBalance}
            disabled={
              !formData.minimumBufferBalance ||
              isFleetOperationPending('setMinimumBufferBalance') ||
              isLoading
            }
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isFleetOperationPending('setMinimumBufferBalance') ? 'Setting...' : 'Set'}
          </button>
        </div>
      </div>

      {/* Fleet Deposit Cap */}
      <div className="bg-gray-100 p-4 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Fleet Deposit Cap ({assetSymbol})
        </label>
        {fleetInfo && (
          <p className="text-sm text-gray-600 mb-2">
            Current:{' '}
            {fleetInfo.depositCap === BigInt(0)
              ? 'Unlimited'
              : `${formatDecimalOutput(fleetInfo.depositCap, assetDecimals)} ${assetSymbol}`}
            {fleetInfo.depositCap > BigInt(0) && fleetInfo.totalAssets > BigInt(0) && (
              <span className="ml-2 text-gray-500">
                (
                {formatPercentage(
                  (fleetInfo.totalAssets * BigInt(100) * BigInt(10 ** 18)) / fleetInfo.depositCap,
                )}{' '}
                used)
              </span>
            )}
          </p>
        )}
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.fleetDepositCap}
            onChange={(e) => handleInputChange('fleetDepositCap', e.target.value)}
            placeholder="0.0"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSetFleetDepositCap}
            disabled={
              !formData.fleetDepositCap ||
              isFleetOperationPending('setFleetDepositCap') ||
              isLoading
            }
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isFleetOperationPending('setFleetDepositCap') ? 'Setting...' : 'Set'}
          </button>
        </div>
      </div>

      {/* Max Rebalance Operations */}
      <div className="bg-gray-100 p-4 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Max Rebalance Operations
        </label>
        {fleetInfo && (
          <p className="text-sm text-gray-600 mb-2">
            Current: {fleetInfo.maxRebalanceOperations.toString()}
          </p>
        )}
        <div className="flex space-x-2">
          <input
            type="number"
            value={formData.maxRebalanceOperations}
            onChange={(e) => handleInputChange('maxRebalanceOperations', e.target.value)}
            placeholder="50"
            min="1"
            max="50"
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <button
            onClick={handleSetMaxRebalanceOperations}
            disabled={
              !formData.maxRebalanceOperations ||
              isFleetOperationPending('setMaxRebalanceOperations') ||
              isLoading
            }
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isFleetOperationPending('setMaxRebalanceOperations') ? 'Setting...' : 'Set'}
          </button>
        </div>
        <p className="text-xs text-gray-500 mt-1">Maximum: 50 operations</p>
      </div>

      {/* Ark Configuration Display */}
      {arks.length > 0 && (
        <div className="bg-gray-100 p-4 rounded-md">
          <h4 className="text-sm font-semibold text-gray-800 mb-4">Ark Configurations</h4>
          <div className="space-y-4">
            {arks.map((ark) => (
              <div key={ark.address} className="border border-gray-300 rounded-md p-3 bg-white">
                <div className="flex items-center justify-between mb-3">
                  <h5 className="text-sm font-medium text-gray-800">{ark.name}</h5>
                  {ark.isBufferArk && (
                    <span className="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full">
                      Buffer Ark
                    </span>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div>
                    <p className="text-gray-600">Deposit Cap</p>
                    <p className="font-medium text-gray-800">
                      {ark.depositCap === BigInt(0)
                        ? 'Unlimited'
                        : `${formatDecimalOutput(ark.depositCap, assetDecimals)} ${assetSymbol}`}
                    </p>
                    {ark.depositCap > BigInt(0) && ark.totalAssets > BigInt(0) && (
                      <p className="text-xs text-gray-500 mt-1">
                        {formatPercentage(
                          (ark.totalAssets * BigInt(100) * BigInt(10 ** 18)) / ark.depositCap,
                        )}{' '}
                        used
                      </p>
                    )}
                  </div>
                  <div>
                    <p className="text-gray-600">Max Deposit % of TVL</p>
                    <p className="font-medium text-gray-800">
                      {ark.maxDepositPercentageOfTVL === BigInt(0)
                        ? 'Unlimited'
                        : formatPercentage(ark.maxDepositPercentageOfTVL)}
                    </p>
                    {fleetInfo &&
                      fleetInfo.totalAssets > BigInt(0) &&
                      ark.totalAssets > BigInt(0) && (
                        <p className="text-xs text-gray-500 mt-1">
                          Current:{' '}
                          {formatPercentage(
                            (ark.totalAssets * BigInt(100) * BigInt(10 ** 18)) /
                              fleetInfo.totalAssets,
                          )}{' '}
                          of fleet TVL
                        </p>
                      )}
                  </div>
                  <div>
                    <p className="text-gray-600">Max Rebalance Inflow</p>
                    <p className="font-medium text-gray-800">
                      {ark.maxRebalanceInflow === BigInt(0) ||
                      ark.maxRebalanceInflow ===
                        BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
                        ? 'Unlimited'
                        : `${formatDecimalOutput(ark.maxRebalanceInflow, assetDecimals)} ${assetSymbol}`}
                    </p>
                  </div>
                  <div>
                    <p className="text-gray-600">Max Rebalance Outflow</p>
                    <p className="font-medium text-gray-800">
                      {ark.maxRebalanceOutflow === BigInt(0) ||
                      ark.maxRebalanceOutflow ===
                        BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
                        ? 'Unlimited'
                        : `${formatDecimalOutput(ark.maxRebalanceOutflow, assetDecimals)} ${assetSymbol}`}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Add New Ark */}
      <div className="bg-gray-100 p-4 rounded-md">
        <label className="block text-sm font-medium text-gray-700 mb-2">Add New Ark</label>
        <div className="flex space-x-2">
          <input
            type="text"
            value={formData.newArkAddress}
            onChange={(e) => handleInputChange('newArkAddress', e.target.value)}
            placeholder="0x..."
            className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
          />
          <button
            onClick={handleAddArk}
            disabled={
              !formData.newArkAddress ||
              isArkOperationPending(`addArk_${formData.newArkAddress}`) ||
              isLoading
            }
            className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isArkOperationPending(`addArk_${formData.newArkAddress}`) ? 'Adding...' : 'Add Ark'}
          </button>
        </div>
        <p className="text-xs text-gray-500 mt-1">
          Enter the address of the ark contract to add to the fleet
        </p>
      </div>

      {/* Enable Transfers - Special Action */}
      <div className="bg-yellow-50 border border-yellow-200 p-4 rounded-md">
        <h4 className="text-sm font-medium text-yellow-800 mb-2">Fleet Token Transferability</h4>
        <p className="text-xs text-yellow-700 mb-3">
          Enable transferability of fleet tokens. This is a one-way action and cannot be undone.
        </p>
        <button
          onClick={handleEnableTransfers}
          disabled={isFleetOperationPending('setFleetTokenTransferability') || isLoading}
          className="px-4 py-2 bg-yellow-600 text-white rounded-md hover:bg-yellow-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isFleetOperationPending('setFleetTokenTransferability')
            ? 'Enabling...'
            : 'Enable Transfers'}
        </button>
      </div>

      {/* Error Display */}
      {hasError && (
        <div className="bg-red-50 border border-red-200 p-3 rounded-md">
          <p className="text-sm text-red-600">
            Error:{' '}
            {fleetWriteError?.message ||
              fleetConfirmError?.message ||
              arkWriteError?.message ||
              arkConfirmError?.message}
          </p>
        </div>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="bg-blue-50 border border-blue-200 p-3 rounded-md">
          <p className="text-sm text-blue-600">
            {isFleetWritePending || isArkWritePending
              ? 'Preparing transaction...'
              : 'Confirming transaction...'}
          </p>
        </div>
      )}
    </div>
  )
}
