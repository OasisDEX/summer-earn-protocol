'use client'

import { useState } from 'react'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'

interface CreateBondModalProps {
  isOpen: boolean
  onClose: () => void
  environment: Environment
  chainId: ChainId
}

export function CreateBondModal({ isOpen, onClose, environment, chainId }: CreateBondModalProps) {
  const { createBond, loading, error, intentBondFactory, tokens } = useIntentSystem(
    environment,
    chainId,
  )

  const [solverAddress, setSolverAddress] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      const hash = await createBond(solverAddress)

      console.log('Bond created:', hash)
      onClose()
      setSolverAddress('')
    } catch (err) {
      console.error('Error creating bond:', err)
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-charcoal-800 rounded-xl p-6 w-full max-w-md mx-4">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-xl font-semibold text-white">Create Solver Bond</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Solver Address */}
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">Solver Address</label>
            <input
              type="text"
              value={solverAddress}
              onChange={(e) => setSolverAddress(e.target.value)}
              placeholder="0x..."
              className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              required
            />
            <p className="text-xs text-gray-400 mt-1">Address of the solver to create a bond for</p>
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
            className="w-full py-3 bg-purple-600 hover:bg-purple-700 disabled:bg-gray-600 text-white font-semibold rounded-lg transition-colors"
          >
            {loading ? 'Creating Bond...' : 'Create Bond'}
          </button>
        </form>

        {/* Contract Info */}
        <div className="mt-6 p-4 bg-charcoal-700/50 rounded-lg">
          <h3 className="text-sm font-medium text-gray-300 mb-2">Contract Information</h3>
          <div className="text-xs text-gray-400 space-y-1">
            <div>IntentBondFactory: {intentBondFactory}</div>
            <div>Summer Token: {tokens?.SUMMER_TOKEN}</div>
            <div>Chain: {chainId === '8453' ? 'Base' : `Chain ${chainId}`}</div>
            <div>Environment: {environment}</div>
          </div>
        </div>

        {/* Bond Info */}
        <div className="mt-4 p-4 bg-purple-900/20 border border-purple-500/30 rounded-lg">
          <h3 className="text-sm font-medium text-purple-300 mb-2">Bond Information</h3>
          <div className="text-xs text-purple-400 space-y-1">
            <div>• Creates individual bond contract for solver</div>
            <div>• Solver can add/remove bond amounts</div>
            <div>• Bond required for solving intents</div>
            <div>• 50% penalty on early resignation</div>
          </div>
        </div>
      </div>
    </div>
  )
}
