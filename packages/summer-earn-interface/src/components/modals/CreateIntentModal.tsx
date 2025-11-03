'use client'

import { useState } from 'react'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'

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
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-charcoal-800 rounded-xl p-6 w-full max-w-md mx-4">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-white">Create Intent</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Ark Address */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Ark Address</label>
            <input
              type="text"
              value={formData.user}
              onChange={(e) => handleInputChange('user', e.target.value)}
              placeholder="0x..."
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Required Notional */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Required Notional (USDC)
            </label>
            <input
              type="number"
              value={formData.requiredNotional}
              onChange={(e) => handleInputChange('requiredNotional', e.target.value)}
              placeholder="1000000"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
            <div className="text-xs text-gray-400 mt-1">
              USDC amount in wei (6 decimals) - enter the raw token amount
            </div>
          </div>

          {/* Required Bond */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Required Bond (USD)
            </label>
            <input
              type="number"
              value={formData.requiredBond}
              onChange={(e) => handleInputChange('requiredBond', e.target.value)}
              placeholder="1000"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
            <div className="text-xs text-gray-400 mt-1">
              USD amount (e.g., enter &quot;1000&quot; for $1000 USD - will be converted to 18
              decimals automatically)
            </div>
          </div>

          {/* Term */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Term (days)</label>
            <input
              type="number"
              value={formData.term}
              onChange={(e) => handleInputChange('term', e.target.value)}
              placeholder="30"
              min="1"
              max="365"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Target Yield */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Target Yield (USDC)
            </label>
            <input
              type="number"
              value={formData.targetYield}
              onChange={(e) => handleInputChange('targetYield', e.target.value)}
              placeholder="50000"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Token */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Token</label>
            <select
              value={formData.token}
              onChange={(e) => handleInputChange('token', e.target.value)}
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
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
            <label className="block text-sm font-medium text-gray-300 mb-2">Oracle Address</label>
            <input
              type="text"
              value={formData.oracle}
              onChange={(e) => handleInputChange('oracle', e.target.value)}
              placeholder="0x..."
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Expiry */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Expiry Date</label>
            <input
              type="datetime-local"
              value={formData.expiry}
              onChange={(e) => handleInputChange('expiry', e.target.value)}
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Error Display */}
          {error && (
            <div className="text-red-400 text-sm bg-red-900/20 p-3 rounded-lg">{error}</div>
          )}

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-2 px-4 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white rounded-lg font-medium transition-colors"
          >
            {loading ? 'Creating...' : 'Create Intent'}
          </button>
        </form>
      </div>
    </div>
  )
}
