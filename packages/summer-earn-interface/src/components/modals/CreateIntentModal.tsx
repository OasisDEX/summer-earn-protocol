'use client'

import { useState } from 'react'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import { formatEther, parseEther } from 'viem'
import type { Environment } from '../../config/environments'
import type { ChainId } from '../../types'

interface CreateIntentModalProps {
  isOpen: boolean
  onClose: () => void
  environment: Environment
  chainId: ChainId
}

export function CreateIntentModal({ isOpen, onClose, environment, chainId }: CreateIntentModalProps) {
  const {
    createIntent,
    loading,
    error,
    tokens,
    genericIntentArk
  } = useIntentSystem(environment, chainId)

  const [formData, setFormData] = useState({
    intentId: '',
    requiredNotional: '',
    term: '',
    targetYield: '',
    summerToken: tokens?.SUMMER_TOKEN || '',
    oracle: '',
    expiry: ''
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    try {
      const expiryTimestamp = Math.floor(new Date(formData.expiry).getTime() / 1000)
      const hash = await createIntent(
        formData.intentId,
        formData.requiredNotional,
        formData.term,
        formData.targetYield,
        formData.summerToken,
        formData.oracle,
        expiryTimestamp.toString()
      )
      
      console.log('Intent created:', hash)
      onClose()
      // Reset form
      setFormData({
        intentId: '',
        requiredNotional: '',
        term: '',
        targetYield: '',
        summerToken: tokens?.SUMMER_TOKEN || '',
        oracle: '',
        expiry: ''
      })
    } catch (err) {
      console.error('Error creating intent:', err)
    }
  }

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }))
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-charcoal-800 rounded-xl p-6 w-full max-w-md mx-4">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-white">Create Intent</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-white transition-colors"
          >
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Intent ID */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Intent ID (bytes32)
            </label>
            <input
              type="text"
              value={formData.intentId}
              onChange={(e) => handleInputChange('intentId', e.target.value)}
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
              placeholder="1000"
              step="0.01"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Term */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Term (seconds)
            </label>
            <input
              type="number"
              value={formData.term}
              onChange={(e) => handleInputChange('term', e.target.value)}
              placeholder="86400"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
            <p className="text-xs text-gray-400 mt-1">
              {formData.term ? `${Math.floor(Number(formData.term) / 86400)} days` : ''}
            </p>
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
              placeholder="50"
              step="0.01"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Summer Token */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Summer Token Address
            </label>
            <input
              type="text"
              value={formData.summerToken}
              onChange={(e) => handleInputChange('summerToken', e.target.value)}
              placeholder="0x..."
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Oracle */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Oracle Address
            </label>
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
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Expiry Date
            </label>
            <input
              type="datetime-local"
              value={formData.expiry}
              onChange={(e) => handleInputChange('expiry', e.target.value)}
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Error Display */}
          {error && (
            <div className="p-3 bg-red-900/20 border border-red-500/30 rounded-lg">
              <p className="text-red-400 text-sm">{error}</p>
            </div>
          )}

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white font-semibold rounded-lg transition-colors"
          >
            {loading ? 'Creating Intent...' : 'Create Intent'}
          </button>
        </form>

        {/* Contract Info */}
        <div className="mt-6 p-4 bg-charcoal-700/50 rounded-lg">
          <h3 className="text-sm font-medium text-gray-300 mb-2">Contract Information</h3>
          <div className="text-xs text-gray-400 space-y-1">
            <div>GenericIntentArk: {genericIntentArk}</div>
            <div>Chain: {chainId === '8453' ? 'Base' : `Chain ${chainId}`}</div>
            <div>Environment: {environment}</div>
          </div>
        </div>
      </div>
    </div>
  )
}
