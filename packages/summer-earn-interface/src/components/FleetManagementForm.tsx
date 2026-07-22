'use client'

import { useState } from 'react'
import { Address } from 'viem'

import { useArkManagement } from '../hooks/useArkManagement'
import { useFleetManagement } from '../hooks/useFleetManagement'
import type { ArkInfo, ChainId, FleetCommanderInfo } from '../types'
import { formatDecimalOutput, formatPercentage } from '../utils/decimals'
import { Badge, Button, helpTextBase, inputBase, labelBase } from './ui'

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
      <h3 className="text-lg font-semibold text-on-surface">Fleet Configuration</h3>

      {/* Minimum Buffer Balance */}
      <div className="bg-white/5 border border-white/10 p-4 rounded-lg">
        <label className={labelBase}>Minimum Buffer Balance ({assetSymbol})</label>
        {fleetInfo && (
          <p className="text-sm text-on-surface-variant mb-2 tabular-nums">
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
            className={`flex-1 ${inputBase}`}
          />
          <Button
            variant="primary"
            onClick={handleSetMinimumBufferBalance}
            disabled={
              !formData.minimumBufferBalance ||
              isFleetOperationPending('setMinimumBufferBalance') ||
              isLoading
            }
          >
            {isFleetOperationPending('setMinimumBufferBalance') ? 'Setting…' : 'Set'}
          </Button>
        </div>
      </div>

      {/* Fleet Deposit Cap */}
      <div className="bg-white/5 border border-white/10 p-4 rounded-lg">
        <label className={labelBase}>Fleet Deposit Cap ({assetSymbol})</label>
        {fleetInfo && (
          <p className="text-sm text-on-surface-variant mb-2 tabular-nums">
            Current:{' '}
            {fleetInfo.depositCap === BigInt(0)
              ? 'Unlimited'
              : `${formatDecimalOutput(fleetInfo.depositCap, assetDecimals)} ${assetSymbol}`}
            {fleetInfo.depositCap > BigInt(0) && fleetInfo.totalAssets > BigInt(0) && (
              <span className="ml-2 text-on-surface-variant/80">
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
            className={`flex-1 ${inputBase}`}
          />
          <Button
            variant="primary"
            onClick={handleSetFleetDepositCap}
            disabled={
              !formData.fleetDepositCap ||
              isFleetOperationPending('setFleetDepositCap') ||
              isLoading
            }
          >
            {isFleetOperationPending('setFleetDepositCap') ? 'Setting…' : 'Set'}
          </Button>
        </div>
      </div>

      {/* Max Rebalance Operations */}
      <div className="bg-white/5 border border-white/10 p-4 rounded-lg">
        <label className={labelBase}>Max Rebalance Operations</label>
        {fleetInfo && (
          <p className="text-sm text-on-surface-variant mb-2 tabular-nums">
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
            className={`flex-1 ${inputBase}`}
          />
          <Button
            variant="primary"
            onClick={handleSetMaxRebalanceOperations}
            disabled={
              !formData.maxRebalanceOperations ||
              isFleetOperationPending('setMaxRebalanceOperations') ||
              isLoading
            }
          >
            {isFleetOperationPending('setMaxRebalanceOperations') ? 'Setting…' : 'Set'}
          </Button>
        </div>
        <p className={helpTextBase}>Maximum: 50 operations</p>
      </div>

      {/* Ark Configuration Display */}
      {arks.length > 0 && (
        <div className="bg-white/5 border border-white/10 p-4 rounded-lg">
          <h4 className="text-sm font-semibold text-on-surface mb-4">Ark Configurations</h4>
          <div className="space-y-4">
            {arks.map((ark) => (
              <div key={ark.address} className="border border-white/10 rounded-lg p-3 bg-white/5">
                <div className="flex items-center justify-between mb-3">
                  <h5 className="text-sm font-medium text-on-surface">{ark.name}</h5>
                  {ark.isBufferArk && (
                    <Badge tone="info" size="sm">
                      Buffer Ark
                    </Badge>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div>
                    <p className="text-on-surface-variant">Deposit Cap</p>
                    <p className="font-medium text-on-surface tabular-nums">
                      {ark.depositCap === BigInt(0)
                        ? 'Unlimited'
                        : `${formatDecimalOutput(ark.depositCap, assetDecimals)} ${assetSymbol}`}
                    </p>
                    {ark.depositCap > BigInt(0) && ark.totalAssets > BigInt(0) && (
                      <p className="text-xs text-on-surface-variant/80 mt-1 tabular-nums">
                        {formatPercentage(
                          (ark.totalAssets * BigInt(100) * BigInt(10 ** 18)) / ark.depositCap,
                        )}{' '}
                        used
                      </p>
                    )}
                  </div>
                  <div>
                    <p className="text-on-surface-variant">Max Deposit % of TVL</p>
                    <p className="font-medium text-on-surface tabular-nums">
                      {ark.maxDepositPercentageOfTVL === BigInt(0)
                        ? 'Unlimited'
                        : formatPercentage(ark.maxDepositPercentageOfTVL)}
                    </p>
                    {fleetInfo &&
                      fleetInfo.totalAssets > BigInt(0) &&
                      ark.totalAssets > BigInt(0) && (
                        <p className="text-xs text-on-surface-variant/80 mt-1 tabular-nums">
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
                    <p className="text-on-surface-variant">Max Rebalance Inflow</p>
                    <p className="font-medium text-on-surface tabular-nums">
                      {ark.maxRebalanceInflow === BigInt(0) ||
                      ark.maxRebalanceInflow ===
                        BigInt('0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
                        ? 'Unlimited'
                        : `${formatDecimalOutput(ark.maxRebalanceInflow, assetDecimals)} ${assetSymbol}`}
                    </p>
                  </div>
                  <div>
                    <p className="text-on-surface-variant">Max Rebalance Outflow</p>
                    <p className="font-medium text-on-surface tabular-nums">
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
      <div className="bg-white/5 border border-white/10 p-4 rounded-lg">
        <label className={labelBase}>Add New Ark</label>
        <div className="flex space-x-2">
          <input
            type="text"
            value={formData.newArkAddress}
            onChange={(e) => handleInputChange('newArkAddress', e.target.value)}
            placeholder="0x…"
            className={`flex-1 ${inputBase} font-mono text-sm`}
          />
          <button
            onClick={handleAddArk}
            disabled={
              !formData.newArkAddress ||
              isArkOperationPending(`addArk_${formData.newArkAddress}`) ||
              isLoading
            }
            className="px-4 py-2 bg-secondary/15 border border-secondary/30 text-secondary hover:bg-secondary/25 rounded-lg disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
          >
            {isArkOperationPending(`addArk_${formData.newArkAddress}`) ? 'Adding…' : 'Add Ark'}
          </button>
        </div>
        <p className={helpTextBase}>Enter the address of the ark contract to add to the fleet</p>
      </div>

      {/* Enable Transfers - Special Action */}
      <div className="bg-warning/10 border border-warning/20 p-4 rounded-lg">
        <h4 className="text-sm font-medium text-warning mb-2">Fleet Token Transferability</h4>
        <p className="text-xs text-warning/80 mb-3">
          Enable transferability of fleet tokens. This is a one-way action and cannot be undone.
        </p>
        <button
          onClick={handleEnableTransfers}
          disabled={isFleetOperationPending('setFleetTokenTransferability') || isLoading}
          className="px-4 py-2 bg-warning/15 border border-warning/30 text-warning hover:bg-warning/25 rounded-lg disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          {isFleetOperationPending('setFleetTokenTransferability')
            ? 'Enabling…'
            : 'Enable Transfers'}
        </button>
      </div>

      {/* Error Display */}
      {hasError && (
        <div className="bg-error/10 border border-error/20 p-3 rounded-lg">
          <p className="text-sm text-error">
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
        <div className="bg-info/10 border border-info/20 p-3 rounded-lg">
          <p className="text-sm text-info">
            {isFleetWritePending || isArkWritePending
              ? 'Preparing transaction…'
              : 'Confirming transaction…'}
          </p>
        </div>
      )}
    </div>
  )
}
