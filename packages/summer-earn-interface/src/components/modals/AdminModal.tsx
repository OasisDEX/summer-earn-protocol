'use client'

import { useState } from 'react'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'

interface AdminModalProps {
  isOpen: boolean
  onClose: () => void
  environment: Environment
  chainId: ChainId
}

export function AdminModal({ isOpen, onClose, environment, chainId }: AdminModalProps) {
  const { loading, error, intentHandler, mockIntentOracle } = useIntentSystem(environment, chainId)

  const [activeTab, setActiveTab] = useState<'escrows' | 'oracle'>('escrows')
  const [formData, setFormData] = useState({
    solverAddress: '',
    asset: '',
  })

  const handleAddSolverEscrow = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      // This would need to be implemented as a keeper function
      console.log('Adding solver escrow for:', formData.solverAddress)
      setFormData((prev) => ({ ...prev, solverAddress: '' }))
    } catch (err) {
      console.error('Error adding solver escrow:', err)
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
          <h2 className="text-xl font-semibold text-white">Admin Functions</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-white transition-colors">
            ✕
          </button>
        </div>

        {/* Tab Navigation */}
        <div className="flex mb-6 border-b border-gray-600">
          <button
            onClick={() => setActiveTab('escrows')}
            className={`px-4 py-2 font-medium transition-colors ${
              activeTab === 'escrows'
                ? 'text-blue-400 border-b-2 border-blue-400'
                : 'text-blue-400 border-b-2 border-blue-400'
            }`}
          >
            Solver Escrows
          </button>
          <button
            onClick={() => setActiveTab('oracle')}
            className={`px-4 py-2 font-medium transition-colors ${
              activeTab === 'oracle'
                ? 'text-blue-400 border-b-2 border-blue-400'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Oracle Status
          </button>
        </div>

        {/* Solver Escrows Tab */}
        {activeTab === 'escrows' && (
          <form onSubmit={handleAddSolverEscrow} className="space-y-4">
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

            <div>
              <label className="block text-sm font-medium text-gray-300 mb-2">Asset</label>
              <input
                type="text"
                value={formData.asset}
                onChange={(e) => handleInputChange('asset', e.target.value)}
                placeholder="0x..."
                className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
                required
              />
            </div>

            {/* Error Display */}
            {error && (
              <div className="text-red-400 text-sm bg-red-900/20 p-3 rounded-lg">{error}</div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-2 px-4 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white rounded-lg font-medium transition-colors"
            >
              {loading ? 'Adding...' : 'Add Solver Escrow'}
            </button>
          </form>
        )}

        {/* Oracle Status Tab */}
        {activeTab === 'oracle' && (
          <div className="space-y-4">
            <div className="bg-charcoal-700/50 p-4 rounded-lg">
              <h3 className="text-sm font-medium text-gray-300 mb-2">Mock Intent Oracle</h3>
              <div className="text-xs text-gray-400 space-y-1">
                <div>Address: {mockIntentOracle}</div>
                <div>Status: Active (Test Mode)</div>
                <div>Supported Tokens: SUMMER, USDC</div>
              </div>
            </div>

            <div className="bg-charcoal-700/50 p-4 rounded-lg">
              <h3 className="text-sm font-medium text-gray-300 mb-2">Oracle Functions</h3>
              <div className="text-xs text-gray-400 space-y-1">
                <div>• addSupportedToken()</div>
                <div>• setPrice()</div>
                <div>• isPriceStale()</div>
              </div>
            </div>

            <div className="bg-yellow-900/20 border border-yellow-500/30 p-4 rounded-lg">
              <h3 className="text-sm font-medium text-yellow-300 mb-2">Note</h3>
              <p className="text-xs text-yellow-400">
                This is a mock oracle for testing. In production, this would be replaced with a real
                price oracle.
              </p>
            </div>
          </div>
        )}

        {/* Contract Info */}
        <div className="mt-6 p-4 bg-charcoal-700/50 rounded-lg">
          <h3 className="text-sm font-medium text-gray-300 mb-2">Contract Information</h3>
          <div className="text-xs text-gray-400 space-y-1">
            <div>IntentHandler: {intentHandler}</div>
            <div>Chain: {chainId === '8453' ? 'Base' : `Chain ${chainId}`}</div>
            <div>Environment: {environment}</div>
          </div>
        </div>
      </div>
    </div>
  )
}
