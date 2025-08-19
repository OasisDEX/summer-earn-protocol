'use client'

import { useState } from 'react'
import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'

interface SolveIntentModalProps {
  isOpen: boolean
  onClose: () => void
  environment: Environment
  chainId: ChainId
}

export function SolveIntentModal({ isOpen, onClose, environment, chainId }: SolveIntentModalProps) {
  const { solveIntent, loading, error, intentHandler } = useIntentSystem(environment, chainId)

  const [formData, setFormData] = useState({
    userAddress: '',
    solverAddress: '',
    escrowedYield: '',
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      const hash = await solveIntent(
        formData.userAddress,
        formData.solverAddress,
        formData.escrowedYield,
      )

      console.log('Intent solved:', hash)
      onClose()
      // Reset form
      setFormData({
        userAddress: '',
        solverAddress: '',
        escrowedYield: '',
      })
    } catch (err) {
      console.error('Error solving intent:', err)
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
          <h2 className="text-xl font-semibold text-white">Solve Intent</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* User Address */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              User Address (Ark)
            </label>
            <input
              type="text"
              value={formData.userAddress}
              onChange={(e) => handleInputChange('userAddress', e.target.value)}
              placeholder="0x..."
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Solver Address */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Solver Address</label>
            <input
              type="text"
              value={formData.solverAddress}
              onChange={(e) => handleInputChange('solverAddress', e.target.value)}
              placeholder="0x..."
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
          </div>

          {/* Escrowed Yield */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Escrowed Yield (USDC)
            </label>
            <input
              type="number"
              value={formData.escrowedYield}
              onChange={(e) => handleInputChange('escrowedYield', e.target.value)}
              placeholder="25"
              step="0.01"
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
            <p className="text-xs text-gray-400 mt-1">
              Amount to escrow upfront as yield guarantee
            </p>
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
            className="w-full py-3 bg-green-600 hover:bg-green-700 disabled:bg-gray-600 text-white font-semibold rounded-lg transition-colors"
          >
            {loading ? 'Solving Intent...' : 'Solve Intent'}
          </button>
        </form>

        {/* Contract Info */}
        <div className="mt-6 p-4 bg-charcoal-700/50 rounded-lg">
          <h3 className="text-sm font-medium text-gray-300 mb-2">Contract Information</h3>
          <div className="text-xs text-gray-400 space-y-1">
            <div>IntentHandler: {intentHandler}</div>
            <div>Chain: {chainId === '8453' ? 'Base' : `Chain ${chainId}`}</div>
            <div>Environment: {environment}</div>
          </div>
        </div>

        {/* Requirements Info */}
        <div className="mt-4 p-4 bg-blue-900/20 border border-blue-500/30 rounded-lg">
          <h3 className="text-sm font-medium text-blue-300 mb-2">Requirements</h3>
          <div className="text-xs text-blue-400 space-y-1">
            <div>• Solver must have sufficient bond</div>
            <div>• Oracle price must not be stale</div>
            <div>• Intent must be in Created state</div>
            <div>• Intent must not be expired</div>
          </div>
        </div>
      </div>
    </div>
  )
}
