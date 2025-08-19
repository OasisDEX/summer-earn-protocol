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
  const { grantSolverRole, addSolverAdapter, loading, error, intentHandler, aaveV3Escrow } =
    useIntentSystem(environment, chainId)

  const [activeTab, setActiveTab] = useState<'roles' | 'adapters'>('roles')
  const [formData, setFormData] = useState({
    solverAddress: '',
    adapterAddress: '',
  })

  const handleGrantSolverRole = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      const hash = await grantSolverRole(formData.solverAddress)
      console.log('Solver role granted:', hash)
      setFormData((prev) => ({ ...prev, solverAddress: '' }))
    } catch (err) {
      console.error('Error granting solver role:', err)
    }
  }

  const handleAddSolverAdapter = async (e: React.FormEvent) => {
    e.preventDefault()

    try {
      const hash = await addSolverAdapter(formData.solverAddress, formData.adapterAddress)
      console.log('Solver adapter added:', hash)
      setFormData({ solverAddress: '', adapterAddress: '' })
    } catch (err) {
      console.error('Error adding solver adapter:', err)
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
            onClick={() => setActiveTab('roles')}
            className={`px-4 py-2 font-medium transition-colors ${
              activeTab === 'roles'
                ? 'text-blue-400 border-b-2 border-blue-400'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Role Management
          </button>
          <button
            onClick={() => setActiveTab('adapters')}
            className={`px-4 py-2 font-medium transition-colors ${
              activeTab === 'adapters'
                ? 'text-blue-400 border-b-2 border-blue-400'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Solver Adapters
          </button>
        </div>

        {/* Role Management Tab */}
        {activeTab === 'roles' && (
          <form onSubmit={handleGrantSolverRole} className="space-y-4">
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
              <p className="text-xs text-gray-400 mt-1">Address to grant SOLVER_ROLE</p>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white font-semibold rounded-lg transition-colors"
            >
              {loading ? 'Granting Role...' : 'Grant Solver Role'}
            </button>
          </form>
        )}

        {/* Solver Adapters Tab */}
        {activeTab === 'adapters' && (
          <form onSubmit={handleAddSolverAdapter} className="space-y-4">
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
              <label className="block text-sm font-medium text-gray-300 mb-2">
                Adapter Address
              </label>
              <input
                type="text"
                value={formData.adapterAddress}
                onChange={(e) => handleInputChange('adapterAddress', e.target.value)}
                placeholder="0x..."
                className="w-full px-3 py-2 bg-charcoal-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
                required
              />
              <p className="text-xs text-gray-400 mt-1">Protocol adapter (e.g., AaveV3Escrow)</p>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 bg-green-600 hover:bg-green-700 disabled:bg-gray-600 text-white font-semibold rounded-lg transition-colors"
            >
              {loading ? 'Adding Adapter...' : 'Add Solver Adapter'}
            </button>
          </form>
        )}

        {/* Error Display */}
        {error && (
          <div className="mt-4 p-3 bg-red-900/20 border border-red-500/30 rounded-lg">
            <p className="text-red-400 text-sm">{error}</p>
          </div>
        )}

        {/* Contract Info */}
        <div className="mt-6 p-4 bg-charcoal-700/50 rounded-lg">
          <h3 className="text-sm font-medium text-gray-300 mb-2">Contract Information</h3>
          <div className="text-xs text-gray-400 space-y-1">
            <div>IntentHandler: {intentHandler}</div>
            <div>AaveV3Escrow: {aaveV3Escrow}</div>
            <div>Chain: {chainId === '8453' ? 'Base' : `Chain ${chainId}`}</div>
            <div>Environment: {environment}</div>
          </div>
        </div>

        {/* Admin Info */}
        <div className="mt-4 p-4 bg-yellow-900/20 border border-yellow-500/30 rounded-lg">
          <h3 className="text-sm font-medium text-yellow-300 mb-2">Admin Functions</h3>
          <div className="text-xs text-yellow-400 space-y-1">
            <div>• Grant/revoke solver roles</div>
            <div>• Add/remove solver adapters</div>
            <div>• Manage system configuration</div>
            <div>• Requires DEFAULT_ADMIN_ROLE</div>
          </div>
        </div>
      </div>
    </div>
  )
}
