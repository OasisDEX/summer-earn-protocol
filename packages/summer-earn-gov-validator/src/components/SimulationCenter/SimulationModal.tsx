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
      <div className="absolute inset-0 bg-bg/80 backdrop-blur-sm" onClick={onClose} />

      <div className="relative w-full max-w-5xl max-h-[90vh] overflow-hidden bg-console-surface border border-line rounded-xl shadow-2xl flex flex-col">
        <div className="flex items-center justify-between p-4.5 border-b border-line">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-pink-bg flex items-center justify-center text-brand-pink">
              <Play size={16} fill="currentColor" />
            </div>
            <div>
              <h2 className="text-base font-semibold text-fg">Simulation Center</h2>
              <p className="text-xs text-fg2">
                Verify multi-chain proposal execution before voting
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 hover:bg-surface3 rounded-lg text-fg2 hover:text-fg transition-colors"
          >
            <X size={18} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6">
          <SimulationCenter results={results} targetChainIds={targetChainIds} />
        </div>

        <div className="p-4.5 border-t border-line flex justify-end gap-2.5 bg-surface2">
          <button
            onClick={onClose}
            className="h-[34px] px-4 rounded-lg border border-line2 bg-surface3 text-fg text-xs font-semibold hover:bg-surface2 transition-colors"
          >
            Close
          </button>
          <button
            onClick={onSimulate}
            disabled={isSimulating}
            className="h-[34px] px-5 bg-brand-gradient text-white rounded-full text-xs font-semibold hover:brightness-110 active:scale-95 transition-all disabled:opacity-50 flex items-center gap-2"
          >
            {isSimulating ? (
              <>
                <span className="w-3.5 h-3.5 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                Simulating...
              </>
            ) : (
              <>
                <Play size={14} fill="currentColor" />
                Run Simulation
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
