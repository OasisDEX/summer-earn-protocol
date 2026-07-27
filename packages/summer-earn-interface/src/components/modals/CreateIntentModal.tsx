'use client'

import { useState } from 'react'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'
import { Button, helpTextBase, inputBase, labelBase, selectBase } from '../ui'
import { Modal } from '../ui/Modal'

interface CreateIntentModalProps {
  isOpen: boolean
  onClose: () => void
  environment: Environment
  chainId: ChainId
}
const DAY_IN_SECONDS = BigInt(86400)
const USD_MULTIPLIER = BigInt(10 ** 18)
export function CreateIntentModal({
  isOpen,
  onClose,
  environment,
  chainId,
}: CreateIntentModalProps) {
  const { createIntent, loading, error, tokens, mockIntentOracle } = useIntentSystem(
    environment,
    chainId,
  )

  const [formData, setFormData] = useState({
    user: '', // Ark address
    requiredNotional: '',
    requiredBond: '', // USD amount with 18 decimals
    term: '',
    targetYield: '',
    token: tokens?.USDC || '',
    oracle: mockIntentOracle || '',
    expiry: '',
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      const expiryTimestamp = Math.floor(new Date(formData.expiry).getTime() / 1000)

      // Create Intent struct matching the contract
      const intent = {
        user: formData.user as `0x${string}`,
        requiredNotional: BigInt(formData.requiredNotional),
        requiredBond: BigInt(formData.requiredBond) * USD_MULTIPLIER, // Convert USD input to 18 decimals
        term: BigInt(formData.term) * DAY_IN_SECONDS,
        targetYield: BigInt(formData.targetYield),
        token: formData.token as `0x${string}`,
        oracle: formData.oracle as `0x${string}`,
        expiry: BigInt(expiryTimestamp),
      }

      const hash = await createIntent(intent)

      console.log('Intent created:', hash)
      onClose()
      // Reset form
      setFormData({
        user: '',
        requiredNotional: '',
        requiredBond: '',
        term: '',
        targetYield: '',
        token: tokens?.USDC || '',
        oracle: mockIntentOracle || '',
        expiry: '',
      })
    } catch (err) {
      console.error('Error creating intent:', err)
    }
  }

  const handleInputChange = (field: string, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }))
  }

  if (!isOpen) return null

  return (
    <Modal onClose={onClose} title="Create Intent" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Ark Address */}
        <div>
          <label className={labelBase}>Ark Address</label>
          <input
            type="text"
            value={formData.user}
            onChange={(e) => handleInputChange('user', e.target.value)}
            placeholder="0x..."
            className={inputBase}
            required
          />
        </div>

        {/* Required Notional */}
        <div>
          <label className={labelBase}>Required Notional (USDC)</label>
          <input
            type="number"
            value={formData.requiredNotional}
            onChange={(e) => handleInputChange('requiredNotional', e.target.value)}
            placeholder="1000000"
            className={inputBase}
            required
          />
          <div className={helpTextBase}>
            USDC amount in wei (6 decimals) - enter the raw token amount
          </div>
        </div>

        {/* Required Bond */}
        <div>
          <label className={labelBase}>Required Bond (USD)</label>
          <input
            type="number"
            value={formData.requiredBond}
            onChange={(e) => handleInputChange('requiredBond', e.target.value)}
            placeholder="1000"
            className={inputBase}
            required
          />
          <div className={helpTextBase}>
            USD amount (e.g., enter &quot;1000&quot; for $1000 USD - will be converted to 18
            decimals automatically)
          </div>
        </div>

        {/* Term */}
        <div>
          <label className={labelBase}>Term (days)</label>
          <input
            type="number"
            value={formData.term}
            onChange={(e) => handleInputChange('term', e.target.value)}
            placeholder="30"
            min="1"
            max="365"
            className={inputBase}
            required
          />
        </div>

        {/* Target Yield */}
        <div>
          <label className={labelBase}>Target Yield (USDC)</label>
          <input
            type="number"
            value={formData.targetYield}
            onChange={(e) => handleInputChange('targetYield', e.target.value)}
            placeholder="50000"
            className={inputBase}
            required
          />
        </div>

        {/* Token */}
        <div>
          <label className={labelBase}>Token</label>
          <select
            value={formData.token}
            onChange={(e) => handleInputChange('token', e.target.value)}
            className={`${selectBase} w-full`}
            required
          >
            <option value="">Select token</option>
            {tokens &&
              Object.entries(tokens).map(([symbol, address]) => (
                <option key={symbol} value={address}>
                  {symbol}
                </option>
              ))}
          </select>
        </div>

        {/* Oracle */}
        <div>
          <label className={labelBase}>Oracle Address</label>
          <input
            type="text"
            value={formData.oracle}
            onChange={(e) => handleInputChange('oracle', e.target.value)}
            placeholder="0x..."
            className={inputBase}
            required
          />
        </div>

        {/* Expiry */}
        <div>
          <label className={labelBase}>Expiry Date</label>
          <input
            type="datetime-local"
            value={formData.expiry}
            onChange={(e) => handleInputChange('expiry', e.target.value)}
            className={inputBase}
            required
          />
        </div>

        {/* Error Display */}
        {error && (
          <div className="text-error text-sm bg-error/15 border border-error/30 p-3 rounded-lg">
            {error}
          </div>
        )}

        {/* Submit Button */}
        <Button type="submit" disabled={loading} variant="primary" fullWidth>
          {loading ? 'Creating...' : 'Create Intent'}
        </Button>
      </form>
    </Modal>
  )
}
