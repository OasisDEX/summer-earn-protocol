'use client'

import React, { useState } from 'react'
import { createPortal } from 'react-dom'

import { useCastVote, VoteSupport } from '@/hooks/useProposalVoting'

interface VotingModalProps {
  proposalId: string
  proposalTitle: string
  governor: string
  isOpen: boolean
  onClose: () => void
}

export function VotingModal({
  proposalId,
  proposalTitle,
  governor,
  isOpen,
  onClose,
}: VotingModalProps) {
  const [selectedVote, setSelectedVote] = useState<'for' | 'against' | 'abstain' | null>(null)
  const [mounted, setMounted] = useState(false)
  const { castVote, isVoting, isSuccess, error, isConnected } = useCastVote(governor)

  // Handle client-side mounting for Portal
  React.useEffect(() => {
    setMounted(true)
  }, [])

  // Handle successful vote
  React.useEffect(() => {
    if (isSuccess) {
      setTimeout(() => {
        onClose()
      }, 2000)
    }
  }, [isSuccess, onClose])

  if (!isOpen || !mounted) return null

  const handleVote = () => {
    if (!selectedVote) return

    const supportMap: Record<string, VoteSupport> = {
      for: 1,
      against: 0,
      abstain: 2,
    }

    castVote(proposalId, supportMap[selectedVote])
  }

  return createPortal(
    <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-background/80 backdrop-blur-md"
        onClick={!isVoting ? onClose : undefined}
      />

      {/* Modal Container */}
      <div className="glass-panel-elevated ice-glow w-full max-w-lg rounded-2xl overflow-hidden shadow-2xl relative z-10 border border-sky-400/20">
        {/* Header */}
        <div className="px-6 py-5 border-b border-white/5 flex items-center justify-between bg-slate-900/40">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shadow-lg shadow-primary/5">
              <span className="material-symbols-outlined text-primary text-2xl font-bold">
                how_to_vote
              </span>
            </div>
            <div>
              <h2 className="text-xl font-bold tracking-tight text-on-surface">Submit Your Vote</h2>
              <p className="text-[10px] text-on-surface-variant font-bold uppercase tracking-widest opacity-60">
                Decision for Proposal #{proposalId.slice(0, 8)}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            disabled={isVoting}
            className="text-on-surface-variant hover:text-on-surface transition-colors p-2 hover:bg-white/5 rounded-lg disabled:opacity-30"
          >
            <span className="material-symbols-outlined">close</span>
          </button>
        </div>

        {/* Success State */}
        {isSuccess ? (
          <div className="p-12 text-center space-y-4">
            <div className="w-20 h-20 bg-emerald-400/10 rounded-full flex items-center justify-center mx-auto mb-6 shadow-xl shadow-emerald-400/5 border border-emerald-400/20">
              <span className="material-symbols-outlined text-emerald-400 text-5xl animate-bounce">
                check_circle
              </span>
            </div>
            <h3 className="text-2xl font-bold text-on-surface tracking-tight">Vote Submitted!</h3>
            <p className="text-on-surface-variant max-w-xs mx-auto">
              Your voice has been recorded on the Base network. Dashboard will update shortly.
            </p>
          </div>
        ) : (
          <>
            {/* Content */}
            <div className="p-6 space-y-6">
              {/* Proposal Preview */}
              <div className="bg-surface-container-lowest/50 rounded-xl p-5 border border-white/5 shadow-inner">
                <h3 className="text-sm font-semibold text-on-surface leading-snug">
                  {proposalTitle}
                </h3>
              </div>

              {/* Vote Options */}
              <div className="space-y-3">
                <button
                  onClick={() => setSelectedVote('for')}
                  disabled={isVoting}
                  className={`w-full flex items-center justify-between p-4 rounded-xl border transition-all text-left group ${
                    selectedVote === 'for'
                      ? 'border-emerald-400 bg-emerald-400/10 shadow-lg shadow-emerald-400/5'
                      : 'border-white/5 bg-white/5 hover:bg-white/10 hover:border-white/10'
                  }`}
                >
                  <div className="flex items-center space-x-4">
                    <div
                      className={`w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all ${
                        selectedVote === 'for'
                          ? 'border-emerald-400 bg-emerald-400/20'
                          : 'border-white/20'
                      }`}
                    >
                      {selectedVote === 'for' && (
                        <div className="w-2.5 h-2.5 bg-emerald-400 rounded-full shadow-[0_0_8px_rgba(52,211,153,0.6)]"></div>
                      )}
                    </div>
                    <span
                      className={`font-bold transition-all ${
                        selectedVote === 'for' ? 'text-emerald-400' : 'text-on-surface'
                      }`}
                    >
                      For
                    </span>
                  </div>
                  <span className="material-symbols-outlined text-emerald-400/40 group-hover:text-emerald-400 transition-colors">
                    trending_up
                  </span>
                </button>

                <button
                  onClick={() => setSelectedVote('against')}
                  disabled={isVoting}
                  className={`w-full flex items-center justify-between p-4 rounded-xl border transition-all text-left group ${
                    selectedVote === 'against'
                      ? 'border-error bg-error/10 shadow-lg shadow-error/5'
                      : 'border-white/5 bg-white/5 hover:bg-white/10 hover:border-white/10'
                  }`}
                >
                  <div className="flex items-center space-x-4">
                    <div
                      className={`w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all ${
                        selectedVote === 'against' ? 'border-error bg-error/20' : 'border-white/20'
                      }`}
                    >
                      {selectedVote === 'against' && (
                        <div className="w-2.5 h-2.5 bg-error rounded-full shadow-[0_0_8px_rgba(255,107,107,0.6)]"></div>
                      )}
                    </div>
                    <span
                      className={`font-bold transition-all ${
                        selectedVote === 'against' ? 'text-error' : 'text-on-surface'
                      }`}
                    >
                      Against
                    </span>
                  </div>
                  <span className="material-symbols-outlined text-error/40 group-hover:text-error transition-colors">
                    trending_down
                  </span>
                </button>

                <button
                  onClick={() => setSelectedVote('abstain')}
                  disabled={isVoting}
                  className={`w-full flex items-center justify-between p-4 rounded-xl border transition-all text-left group ${
                    selectedVote === 'abstain'
                      ? 'border-slate-400 bg-slate-400/10 shadow-lg shadow-slate-400/5'
                      : 'border-white/5 bg-white/5 hover:bg-white/10 hover:border-white/10'
                  }`}
                >
                  <div className="flex items-center space-x-4">
                    <div
                      className={`w-6 h-6 rounded-full border-2 flex items-center justify-center transition-all ${
                        selectedVote === 'abstain'
                          ? 'border-slate-400 bg-slate-400/20'
                          : 'border-white/20'
                      }`}
                    >
                      {selectedVote === 'abstain' && (
                        <div className="w-2.5 h-2.5 bg-slate-400 rounded-full shadow-[0_0_8px_rgba(148,163,184,0.6)]"></div>
                      )}
                    </div>
                    <span
                      className={`font-bold transition-all ${
                        selectedVote === 'abstain' ? 'text-slate-400' : 'text-on-surface'
                      }`}
                    >
                      Abstain
                    </span>
                  </div>
                  <span className="material-symbols-outlined text-slate-400/40 group-hover:text-slate-400 transition-colors">
                    remove_circle
                  </span>
                </button>
              </div>

              {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl p-4 text-error text-xs font-semibold flex items-center gap-2 animate-pulse">
                  <span className="material-symbols-outlined text-sm">error</span>
                  {error.message || 'Failed to cast vote'}
                </div>
              )}

              {!isConnected && (
                <div className="bg-amber-400/10 border border-amber-400/20 rounded-xl p-4 text-amber-500 text-xs font-semibold flex items-center gap-2">
                  <span className="material-symbols-outlined text-sm">warning</span>
                  Please connect your wallet to participate
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="p-6 bg-slate-950/60 border-t border-white/5 flex space-x-4">
              <button
                onClick={onClose}
                disabled={isVoting}
                className="flex-1 px-4 py-3.5 rounded-xl border border-white/10 text-on-surface font-bold hover:bg-white/5 active:scale-95 transition-all text-center text-sm disabled:opacity-30"
              >
                Cancel
              </button>
              <button
                onClick={handleVote}
                disabled={!selectedVote || isVoting || !isConnected}
                className={`flex-[2] px-4 py-3.5 rounded-xl font-bold shadow-xl hover:brightness-110 active:scale-95 transition-all flex items-center justify-center gap-3 text-sm ${
                  selectedVote && isConnected
                    ? 'bg-primary text-on-primary shadow-primary/20 cursor-pointer'
                    : 'bg-slate-800 text-slate-500 cursor-not-allowed border border-white/5'
                }`}
              >
                {isVoting ? (
                  <>
                    <span className="material-symbols-outlined animate-spin text-lg">sync</span>
                    Broadcasting...
                  </>
                ) : (
                  <>
                    <span>Confirm Vote</span>
                    <span className="material-symbols-outlined text-lg">arrow_forward</span>
                  </>
                )}
              </button>
            </div>
          </>
        )}
      </div>
    </div>,
    document.body,
  )
}
