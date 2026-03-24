'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'

import { BottomNavBar } from '@/components/BottomNavBar'
import { TopNavBar } from '@/components/TopNavBar'
import { useCastVote, VoteSupport } from '@/hooks/useProposalVoting'
import { getMockProposalById } from '@/services/mockData'

interface PageProps {
  params: Promise<{ id: string }>
}

// Client component for voting modal
export default function VoteModalPage({ params }: PageProps) {
  const router = useRouter()
  const [proposalId, setProposalId] = useState<string>('')
  const [selectedVote, setSelectedVote] = useState<'for' | 'against' | 'abstain' | null>(null)

  const { castVote, isVoting, isSuccess, error, isConnected } = useCastVote()

  useEffect(() => {
    params.then((resolvedParams) => {
      setProposalId(resolvedParams.id)
    })
  }, [params])

  useEffect(() => {
    if (isSuccess) {
      router.push('/proposals')
    }
  }, [isSuccess, router])

  const proposal = proposalId ? getMockProposalById(proposalId) : null

  const handleVote = () => {
    if (!selectedVote || !proposalId) return

    const supportMap: Record<string, VoteSupport> = {
      for: 1,
      against: 0,
      abstain: 2,
    }

    castVote(proposalId, supportMap[selectedVote])
  }

  if (!proposal) {
    return (
      <div className="flex flex-col min-h-screen">
        <TopNavBar />
        <main className="flex-1 flex items-center justify-center">
          <div className="text-center">
            <span className="material-symbols-outlined text-6xl text-slate-600 mb-4">error</span>
            <p className="text-on-surface-variant">Proposal not found</p>
            <Link href="/proposals" className="text-primary mt-4 inline-block">
              Back to Proposals
            </Link>
          </div>
        </main>
      </div>
    )
  }

  return (
    <div className="flex flex-col min-h-screen">
      <TopNavBar />
      <main className="relative w-full flex-1 p-6 md:p-12 flex flex-col items-center justify-center">
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-background/80 backdrop-blur-sm p-4">
          <div className="glass-panel-elevated ice-glow w-full max-w-lg rounded-xl overflow-hidden shadow-2xl">
            {/* Header */}
            <div className="px-6 py-5 border-b border-white/5 flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
                  <span className="material-symbols-outlined text-primary text-xl">
                    how_to_vote
                  </span>
                </div>
                <h2 className="text-xl font-semibold tracking-tight">Submit Your Vote</h2>
              </div>
              <Link
                href={`/proposal/${proposal.id}`}
                className="text-on-surface-variant hover:text-on-surface transition-colors"
              >
                <span className="material-symbols-outlined">close</span>
              </Link>
            </div>

            {/* Content */}
            <div className="p-6 space-y-8">
              {/* Proposal Preview */}
              <div className="bg-surface-container-low rounded-lg p-4 border border-white/5">
                <div className="flex justify-between items-center mb-1">
                  <span className="text-[10px] font-bold uppercase tracking-widest text-primary">
                    Proposal #{proposal.id}
                  </span>
                </div>
                <h3 className="text-sm font-medium text-on-surface leading-snug">
                  {proposal.title}
                </h3>
              </div>

              {/* Vote Options */}
              <div className="space-y-3">
                <button
                  onClick={() => setSelectedVote('for')}
                  className={`w-full flex items-center justify-between p-4 rounded-lg border transition-all text-left ${
                    selectedVote === 'for'
                      ? 'border-primary bg-primary/10'
                      : 'border-primary/20 bg-primary/5 hover:bg-primary/10'
                  }`}
                >
                  <div className="flex items-center space-x-4">
                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center p-0.5 ${
                        selectedVote === 'for' ? 'border-primary' : 'border-primary/30'
                      }`}
                    >
                      {selectedVote === 'for' && (
                        <div className="w-full h-full bg-primary rounded-full"></div>
                      )}
                    </div>
                    <span
                      className={`font-semibold ${
                        selectedVote === 'for' ? 'text-primary' : 'text-primary'
                      }`}
                    >
                      For
                    </span>
                  </div>
                </button>

                <button
                  onClick={() => setSelectedVote('against')}
                  className={`w-full flex items-center justify-between p-4 rounded-lg border transition-all text-left ${
                    selectedVote === 'against'
                      ? 'border-error bg-error/10'
                      : 'border-error/20 bg-error/5 hover:bg-error/10'
                  }`}
                >
                  <div className="flex items-center space-x-4">
                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center p-0.5 ${
                        selectedVote === 'against' ? 'border-error' : 'border-error/30'
                      }`}
                    >
                      {selectedVote === 'against' && (
                        <div className="w-full h-full bg-error rounded-full"></div>
                      )}
                    </div>
                    <span
                      className={`font-semibold ${
                        selectedVote === 'against' ? 'text-error' : 'text-error'
                      }`}
                    >
                      Against
                    </span>
                  </div>
                </button>

                <button
                  onClick={() => setSelectedVote('abstain')}
                  className={`w-full flex items-center justify-between p-4 rounded-lg border transition-all text-left ${
                    selectedVote === 'abstain'
                      ? 'border-slate-400 bg-slate-400/10'
                      : 'border-slate-400/20 bg-slate-400/5 hover:bg-slate-400/10'
                  }`}
                >
                  <div className="flex items-center space-x-4">
                    <div
                      className={`w-5 h-5 rounded-full border-2 flex items-center justify-center p-0.5 ${
                        selectedVote === 'abstain' ? 'border-slate-400' : 'border-slate-400/30'
                      }`}
                    >
                      {selectedVote === 'abstain' && (
                        <div className="w-full h-full bg-slate-400 rounded-full"></div>
                      )}
                    </div>
                    <span className="font-semibold text-slate-400">Abstain</span>
                  </div>
                </button>
              </div>

              {error && (
                <div className="bg-error/10 border border-error/20 rounded-lg p-3 text-error text-sm">
                  {error.message || 'Failed to cast vote'}
                </div>
              )}

              {!isConnected && (
                <div className="bg-error/10 border border-error/20 rounded-lg p-3 text-error text-sm">
                  Please connect your wallet to vote
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="p-6 bg-slate-950/40 border-t border-white/5 flex space-x-3">
              <Link
                href={`/proposal/${proposal.id}`}
                className="flex-1 px-4 py-3 rounded-lg border border-white/10 text-on-surface font-semibold hover:bg-white/5 active:scale-95 transition-all text-center"
              >
                Cancel
              </Link>
              <button
                onClick={handleVote}
                disabled={!selectedVote || isVoting || !isConnected}
                className={`flex-[2] px-4 py-3 rounded-lg font-bold shadow-lg hover:brightness-110 active:scale-95 transition-all flex items-center justify-center gap-2 ${
                  selectedVote && isConnected
                    ? 'bg-primary text-on-primary shadow-primary/20'
                    : 'bg-slate-600 text-slate-400 cursor-not-allowed'
                }`}
              >
                {isVoting ? (
                  <>
                    <span className="material-symbols-outlined animate-spin">sync</span>
                    Voting...
                  </>
                ) : (
                  'Confirm Vote'
                )}
              </button>
            </div>
          </div>
        </div>
      </main>
      <BottomNavBar />
    </div>
  )
}
