'use client'

import React from 'react'
import { Play, X } from 'lucide-react'

import { SimulationResult } from '@/types/tenderly'

import { SimulationCenter } from './SimulationCenter'

interface SimulationModalProps {
  isOpen: boolean
  onClose: () => void
  results: Record<string, SimulationResult>
  isSimulating: boolean
  onSimulate: () => void
  targetChainIds: string[]
}

export function SimulationModal({
  isOpen,
  onClose,
  results,
  isSimulating,
  onSimulate,
  targetChainIds,
}: SimulationModalProps) {
  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-background/80 backdrop-blur-sm animate-in fade-in duration-300"
        onClick={onClose}
      />

      {/* Modal Container */}
      <div className="relative w-full max-w-6xl max-h-[90vh] overflow-hidden bg-surface-container-lowest border border-outline-variant shadow-2xl rounded-3xl animate-in zoom-in-95 fade-in duration-300 flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-outline-variant">
          <div className="flex items-center gap-4">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
              <Play className="text-primary" size={20} fill="currentColor" />
            </div>
            <div>
              <h2 className="text-xl font-bold tracking-tight">Simulation Center</h2>
              <p className="text-xs text-on-surface-variant font-medium">
                Verify multi-chain proposal execution before voting
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-surface-container-high rounded-full transition-colors"
          >
            <X size={20} />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-8">
          <SimulationCenter results={results} targetChainIds={targetChainIds} />
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-outline-variant flex justify-end gap-3 bg-surface-container-low">
          <button
            onClick={onClose}
            className="px-6 py-2.5 rounded-xl text-sm font-bold hover:bg-surface-container-high transition-colors"
          >
            Close
          </button>
          <button
            onClick={onSimulate}
            disabled={isSimulating}
            className="px-8 py-2.5 bg-primary text-on-primary rounded-xl text-sm font-black shadow-lg shadow-primary/20 hover:brightness-110 active:scale-95 transition-all disabled:opacity-50 flex items-center gap-2"
          >
            {isSimulating ? (
              <>
                <span className="w-4 h-4 border-2 border-on-primary/20 border-t-on-primary rounded-full animate-spin" />
                Simulating...
              </>
            ) : (
              <>
                <Play size={16} fill="currentColor" />
                Run Simulation
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
