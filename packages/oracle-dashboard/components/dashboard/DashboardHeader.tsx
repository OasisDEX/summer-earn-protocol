'use client'

import { useState } from 'react'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
import { NetworkType } from '../../hooks/useOracleData'

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

interface DashboardHeaderProps {
  title: string
  selectedNetwork: NetworkType
  onNetworkChange: (network: NetworkType) => void
  loading: boolean
  onRefresh: () => void
  onBatchUpdate: () => void
  canBatchUpdate: boolean
  isSelectionMode: boolean
  selectedCount: number
  onCancelSelection: () => void
}

export function DashboardHeader({
  title,
  selectedNetwork,
  onNetworkChange,
  loading,
  onRefresh,
  onBatchUpdate,
  canBatchUpdate,
  isSelectionMode,
  selectedCount,
  onCancelSelection,
}: DashboardHeaderProps) {
  const [isNetworkMenuOpen, setIsNetworkMenuOpen] = useState(false)

  return (
    <header className="h-20 bg-white/80 dark:bg-background-dark/80 backdrop-blur-md border-b border-primary/5 flex items-center justify-between px-8">
      <div className="flex items-center gap-3">
        <h1 className="text-xl font-bold">{title}</h1>
        <div className="h-6 w-px bg-slate-200 dark:bg-slate-700 mx-2"></div>

        <div className="relative">
          <button
            onClick={() => setIsNetworkMenuOpen(!isNetworkMenuOpen)}
            className="flex items-center gap-2 bg-slate-100 dark:bg-slate-800 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-200 transition-colors"
          >
            <div className="w-5 h-5 rounded-full bg-primary/20 flex items-center justify-center">
              <span className="material-icons-round text-primary text-[14px]">public</span>
            </div>
            <span className="text-sm font-bold uppercase tracking-wide">{selectedNetwork}</span>
            <span className="material-icons-round text-slate-400 text-sm">expand_more</span>
          </button>

          {isNetworkMenuOpen && (
            <>
              <div className="fixed inset-0 z-40" onClick={() => setIsNetworkMenuOpen(false)}></div>
              <div className="absolute top-full left-0 mt-2 w-40 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl shadow-xl overflow-hidden z-50 animate-in fade-in zoom-in-95 duration-100">
                <button
                  onClick={() => {
                    onNetworkChange('base')
                    setIsNetworkMenuOpen(false)
                  }}
                  className="w-full text-left px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-800 text-sm font-bold flex items-center gap-2 transition-colors"
                >
                  <div className="w-2 h-2 rounded-full bg-blue-500"></div> Base
                </button>
                <button
                  onClick={() => {
                    onNetworkChange('arbitrum')
                    setIsNetworkMenuOpen(false)
                  }}
                  className="w-full text-left px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-800 text-sm font-bold flex items-center gap-2 transition-colors"
                >
                  <div className="w-2 h-2 rounded-full bg-blue-600"></div> Arbitrum
                </button>
                <button
                  onClick={() => {
                    onNetworkChange('mainnet')
                    setIsNetworkMenuOpen(false)
                  }}
                  className="w-full text-left px-4 py-3 hover:bg-slate-50 dark:hover:bg-slate-800 text-sm font-bold flex items-center gap-2 transition-colors"
                >
                  <div className="w-2 h-2 rounded-full bg-slate-500"></div> Mainnet
                </button>
              </div>
            </>
          )}
        </div>
      </div>
      <div className="flex items-center gap-6">
        <div className="hidden md:flex items-center gap-2 text-slate-400">
          <span className="material-icons-round text-sm">schedule</span>
          <span className="text-sm font-medium">Auto-refresh active</span>
        </div>

        {isSelectionMode ? (
          <div className="flex items-center gap-2">
            <button
              onClick={onCancelSelection}
              className="flex items-center gap-2 bg-slate-100 hover:bg-slate-200 text-slate-600 px-3 py-1.5 rounded-lg transition-colors"
            >
              <span className="text-sm font-bold uppercase tracking-wide">Cancel</span>
            </button>
            <button
              onClick={onBatchUpdate}
              disabled={selectedCount === 0}
              className="flex items-center gap-2 bg-primary hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed text-white px-3 py-1.5 rounded-lg transition-colors shadow-lg shadow-primary/20"
            >
              <span className="material-icons-round text-sm">layers</span>
              <span className="text-sm font-bold uppercase tracking-wide">
                Update ({selectedCount})
              </span>
            </button>
          </div>
        ) : (
          canBatchUpdate && (
            <button
              onClick={onBatchUpdate}
              className="flex items-center gap-2 bg-primary/10 hover:bg-primary/20 text-primary px-3 py-1.5 rounded-lg transition-colors border border-primary/20"
            >
              <span className="material-icons-round text-sm">checklist</span>
              <span className="text-sm font-bold uppercase tracking-wide">Select Updates</span>
            </button>
          )
        )}

        <button
          onClick={onRefresh}
          className="p-2 hover:bg-slate-100 rounded-full transition-colors"
        >
          <span className={cn('material-icons-round text-slate-400', loading && 'animate-spin')}>
            refresh
          </span>
        </button>
        <appkit-button />
      </div>
    </header>
  )
}
