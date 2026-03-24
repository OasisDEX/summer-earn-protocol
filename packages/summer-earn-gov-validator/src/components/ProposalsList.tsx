'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'

import { VoteBar } from '@/components/VoteBar'
import { useMultipleProposalVoting } from '@/hooks/useProposalVoting'
interface ProposalData {
  id: string
  displayId?: string | null
  status:
    | 'Active'
    | 'Executed'
    | 'Queued'
    | 'Defeated'
    | 'Executed on Hub'
    | 'Succeeded'
    | 'Canceled'
  chain: string
  title: string
  description: string
  quorumProgress: number
  timeRemaining: string
  forVotes: number
  againstVotes: number
  abstainVotes: number
  forPercent: number
  againstPercent: number
  abstainPercent: number
  quorumReached: boolean
  targets?: string[]
  values?: string[]
  calldatas?: string[]
}

interface ProposalsListProps {
  initialProposals: ProposalData[]
}

type FilterStatus =
  | 'All'
  | 'Active'
  | 'Executed'
  | 'Executed on Hub'
  | 'Queued'
  | 'Defeated'
  | 'Canceled'

export function ProposalsList({ initialProposals }: ProposalsListProps) {
  const [filter, setFilter] = useState<FilterStatus>('All')
  const [visibleCount, setVisibleCount] = useState(6)

  const proposalIds = useMemo(() => initialProposals.map((p) => p.id), [initialProposals])

  const {
    proposalData,
    totalSupply,
    isLoading: votesLoading,
  } = useMultipleProposalVoting(proposalIds)

  const proposalsWithVotes = useMemo(() => {
    return initialProposals.map((proposal) => {
      if (!proposalData[proposal.id] || !proposalData[proposal.id].votes) {
        return proposal
      }

      const votes = proposalData[proposal.id].votes
      const forVotes = Number(votes.forVotes) / 1e18
      const againstVotes = Number(votes.againstVotes) / 1e18
      const abstainVotes = Number(votes.abstainVotes) / 1e18
      const totalVotes = forVotes + againstVotes + abstainVotes

      const forPercent = totalVotes > 0 ? Math.round((forVotes / totalVotes) * 100) : 0
      const againstPercent = totalVotes > 0 ? Math.round((againstVotes / totalVotes) * 100) : 0
      const abstainPercent = totalVotes > 0 ? Math.round((abstainVotes / totalVotes) * 100) : 0

      // Quorum is 15% of total supply (dynamic from token contract)
      const QUORUM_THRESHOLD = 0.15 * (Number(totalSupply) / 1e18)
      const quorumReached = forVotes >= QUORUM_THRESHOLD

      return {
        ...proposal,
        forVotes,
        againstVotes,
        abstainVotes,
        forPercent,
        againstPercent,
        abstainPercent,
        quorumReached,
        quorumProgress: (forVotes / QUORUM_THRESHOLD) * 100,
      }
    })
  }, [initialProposals, proposalData, totalSupply])

  const filteredProposals = proposalsWithVotes.filter((p) => {
    if (filter === 'All') return true
    return p.status === filter
  })

  const visibleProposals = filteredProposals.slice(0, visibleCount)
  const hasMore = visibleCount < filteredProposals.length

  const isLoading = votesLoading && proposalIds.length > 0

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Active':
        return 'bg-primary/20 text-primary border-primary/30'
      case 'Executed':
        return 'bg-emerald-400/20 text-emerald-400 border-emerald-400/30'
      case 'Executed on Hub':
        return 'bg-amber-400/20 text-amber-500 border-amber-400/30'
      case 'Queued':
        return 'bg-tertiary/20 text-tertiary border-tertiary/30'
      case 'Succeeded':
        return 'bg-emerald-400/20 text-emerald-400 border-emerald-400/30'
      case 'Defeated':
      case 'Canceled':
        return 'bg-error/20 text-error border-error/30'
      default:
        return 'bg-slate-500/20 text-slate-400 border-slate-500/30'
    }
  }
  const getBarColor = (status: string) => {
    switch (status) {
      case 'Active':
        return 'bg-primary shadow-[0_0_15px_rgba(125,211,252,0.4)]'
      case 'Executed':
      case 'Succeeded':
        return 'bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.4)]'
      case 'Executed on Hub':
        return 'bg-amber-400 shadow-[0_0_15px_rgba(251,191,36,0.4)]'
      case 'Queued':
        return 'bg-tertiary shadow-[0_0_15px_rgba(200,160,240,0.4)]'
      case 'Defeated':
      case 'Canceled':
        return 'bg-error shadow-[0_0_15px_rgba(255,107,107,0.4)]'
      default:
        return 'bg-slate-500 shadow-[0_0_15px_rgba(100,116,139,0.4)]'
    }
  }

  return (
    <div className="flex flex-col min-h-screen">
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-10">
        <div>
          <h1 className="text-4xl font-extrabold tracking-tighter text-on-surface mb-2">
            Governance Proposals
          </h1>
          <p className="text-on-surface-variant max-w-xl">
            Shape the future of Summer DAO. Cast your vote on active protocol upgrades and treasury
            allocations.
          </p>
        </div>
        <div className="flex gap-3">
          <Link
            href="/create-proposal"
            className="bg-primary text-on-primary px-6 py-2.5 rounded-lg font-semibold flex items-center gap-2 hover:opacity-90 active:scale-95 transition-all shadow-[0_0_20px_rgba(125,211,252,0.3)]"
          >
            <span className="material-symbols-outlined">add_circle</span>
            New Proposal
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 mb-8">
        <div className="lg:col-span-12 glass-panel p-1 rounded-xl flex overflow-x-auto no-scrollbar">
          {(
            [
              'All',
              'Active',
              'Executed',
              'Executed on Hub',
              'Queued',
              'Defeated',
              'Canceled',
            ] as FilterStatus[]
          ).map((status) => (
            <button
              key={status}
              onClick={() => {
                setFilter(status)
                setVisibleCount(3)
              }}
              className={`px-6 py-2 rounded-lg font-medium text-sm whitespace-nowrap transition-colors ${
                filter === status
                  ? 'bg-primary/10 text-primary'
                  : 'text-on-surface-variant hover:text-on-surface'
              }`}
            >
              {status}
            </button>
          ))}
        </div>
      </div>

      {isLoading && (
        <div className="flex items-center justify-center py-8 mb-4">
          <div className="flex items-center gap-3 text-on-surface-variant">
            <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin"></div>
            <span className="text-sm font-medium">Loading vote data...</span>
          </div>
        </div>
      )}

      <div className="space-y-4">
        {visibleProposals.map((proposal) => (
          <div
            key={proposal.id}
            className="glass-panel hover:glass-panel-elevated hover:scale-[1.01] transition-all duration-300 p-6 rounded-2xl flex flex-col md:flex-row gap-6 items-start md:items-center group shadow-lg relative overflow-hidden"
          >
            {/* Partial Frame / Status Bar */}
            <div
              className={`absolute left-0 top-1/2 -translate-y-1/2 w-1 h-[100%] rounded-r-full transition-all duration-500 group-hover:h-[65%] ${getBarColor(
                proposal.status,
              )}`}
            />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-3 mb-2">
                <span className="text-xs font-bold text-primary tracking-widest uppercase">
                  {proposal.displayId || proposal.id.slice(0, 8)}
                </span>
                <span
                  className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${getStatusColor(proposal.status)}`}
                >
                  {proposal.status}
                </span>
                <span className="flex items-center gap-1 text-xs text-on-surface-variant">
                  <span className="material-symbols-outlined text-sm">hub</span>
                  {proposal.chain}
                </span>
              </div>
              <h3 className="text-xl font-bold text-on-surface group-hover:text-primary transition-colors mb-1 truncate">
                {proposal.title}
              </h3>
              <p className="text-sm text-on-surface-variant line-clamp-1 mb-4">
                {proposal.description}
              </p>
              <div className="flex flex-col gap-3 min-w-[280px]">
                {(proposal.status === 'Active' ||
                  proposal.status === 'Queued' ||
                  proposal.status === 'Executed' ||
                  proposal.status === 'Executed on Hub' ||
                  proposal.status === 'Succeeded') && (
                  <div className="space-y-2">
                    <div className="flex justify-between items-center mb-1">
                      <div className="flex items-center gap-2">
                        <span className="material-symbols-outlined text-slate-400 text-sm">
                          ballot
                        </span>
                        <span className="text-xs font-bold text-on-surface-variant uppercase tracking-wider">
                          Voting Results
                        </span>
                      </div>
                      <span
                        className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${
                          proposal.quorumReached
                            ? 'bg-emerald-400/10 text-emerald-400 border border-emerald-400/20'
                            : 'bg-primary/10 text-primary border border-primary/20 shadow-[0_0_8px_rgba(125,211,252,0.4)]'
                        }`}
                      >
                        {proposal.quorumReached ? 'QUORUM REACHED' : 'QUORUM NOT REACHED'}
                      </span>
                    </div>
                    <div className="w-full">
                      <VoteBar
                        for={proposal.forPercent}
                        against={proposal.againstPercent}
                        abstain={proposal.abstainPercent}
                      />
                    </div>
                  </div>
                )}
                {proposal.status === 'Active' && (
                  <div className="flex items-center gap-2">
                    <span className="material-symbols-outlined text-slate-400 text-sm">
                      schedule
                    </span>
                    <span className="text-xs text-on-surface-variant">
                      Ends in{' '}
                      <span className="text-on-surface font-semibold">
                        {proposal.timeRemaining}
                      </span>
                    </span>
                  </div>
                )}
              </div>
            </div>
            <div className="flex md:flex-col gap-3 w-full md:w-auto">
              <Link
                href={`/proposal/${proposal.id}`}
                className="flex-1 md:w-40 py-2.5 rounded-lg border border-primary/20 text-primary text-sm font-semibold hover:bg-primary/10 transition-all flex items-center justify-center gap-2"
              >
                View Details
              </Link>
            </div>
          </div>
        ))}
      </div>

      {hasMore && (
        <div className="mt-8 text-center">
          <button
            onClick={() => setVisibleCount((prev) => prev + 3)}
            className="px-8 py-3 rounded-lg border border-outline text-on-surface-variant hover:text-on-surface hover:border-primary/30 transition-colors font-medium"
          >
            View More
          </button>
        </div>
      )}

      {filteredProposals.length === 0 && (
        <div className="text-center py-12">
          <span className="material-symbols-outlined text-6xl text-slate-600 mb-4">search_off</span>
          <p className="text-on-surface-variant">No proposals found</p>
        </div>
      )}
    </div>
  )
}
