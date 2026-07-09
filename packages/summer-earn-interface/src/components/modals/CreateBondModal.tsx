'use client'

import { useState } from 'react'

import type { Environment } from '../../config/environments'
import { useIntentSystem } from '../../hooks/useIntentSystem'
import type { ChainId } from '../../types'
import { AddressDisplay, Button, helpTextBase, inputBase, labelBase } from '../ui'
import { Modal } from '../ui/Modal'

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
    <Modal onClose={onClose} title="Create Solver Bond" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Solver Address */}
        <div>
          <label className={labelBase}>Solver Address</label>
          <input
            type="text"
            value={solverAddress}
            onChange={(e) => setSolverAddress(e.target.value)}
            placeholder="0x..."
            className={inputBase}
            required
          />
          <p className={helpTextBase}>Address of the solver to create a bond for</p>
        </div>

        {/* Error Display */}
        {error && (
          <div className="p-3 bg-error/15 border border-error/30 rounded-lg">
            <p className="text-error text-sm">{error}</p>
          </div>
        )}

        {/* Submit Button */}
        <Button type="submit" disabled={loading} variant="primary" size="lg" fullWidth>
          {loading ? 'Creating Bond...' : 'Create Bond'}
        </Button>
      </form>

      {/* Contract Info */}
      <div className="mt-6 p-4 bg-white/[0.02] border border-white/5 rounded-lg">
        <h3 className="text-sm font-medium text-on-surface-variant mb-2">Contract Information</h3>
        <div className="text-xs text-on-surface-variant space-y-1">
          <div>
            IntentBondFactory: <AddressDisplay value={intentBondFactory} chars={6} />
          </div>
          <div>
            Summer Token: <AddressDisplay value={tokens?.SUMMER_TOKEN} chars={6} />
          </div>
          <div>Chain: {chainId === '8453' ? 'Base' : `Chain ${chainId}`}</div>
          <div>Environment: {environment}</div>
        </div>
      </div>

      {/* Bond Info */}
      <div className="mt-4 p-4 bg-primary/10 border border-primary/20 rounded-lg">
        <h3 className="text-sm font-medium text-primary mb-2">Bond Information</h3>
        <div className="text-xs text-primary/80 space-y-1">
          <div>• Creates individual bond contract for solver</div>
          <div>• Solver can add/remove bond amounts</div>
          <div>• Bond required for solving intents</div>
          <div>• 50% penalty on early resignation</div>
        </div>
      </div>
    </Modal>
  )
}
