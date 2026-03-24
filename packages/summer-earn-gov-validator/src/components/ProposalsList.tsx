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

type FilterChain = 'All' | 'Mainnet' | 'Base' | 'Arbitrum' | 'Sonic' | 'Hyperliquid'

const CHAIN_METADATA: Record<
  string,
  { icon: string; color: string; bgColor: string; borderColor: string; accentColor: string }
> = {
  Mainnet: {
    icon: 'hub',
    color: 'text-slate-400',
    bgColor: 'bg-slate-400/10',
    borderColor: 'border-slate-600',
    accentColor: 'bg-slate-600',
  },
  Base: {
    icon: 'change_history',
    color: 'text-tertiary',
    bgColor: 'bg-tertiary/10',
    borderColor: 'border-tertiary',
    accentColor: 'bg-tertiary',
  },
  Arbitrum: {
    icon: 'token',
    color: 'text-sky-400',
    bgColor: 'bg-sky-400/10',
    borderColor: 'border-sky-500',
    accentColor: 'bg-sky-500',
  },
  Sonic: {
    icon: 'waves',
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    borderColor: 'border-primary',
    accentColor: 'bg-primary',
  },
  Hyperliquid: {
    icon: 'bolt',
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    borderColor: 'border-primary',
    accentColor: 'bg-primary',
  },
  'Multi-Chain': {
    icon: 'hub',
    color: 'text-slate-400',
    bgColor: 'bg-slate-400/10',
    borderColor: 'border-slate-600',
    accentColor: 'bg-slate-600',
  },
}

export function ProposalsList({ initialProposals }: ProposalsListProps) {
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('All')
  const [chainFilter, setChainFilter] = useState<FilterChain>('All')
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

  const filteredProposals = proposalsWithVotes.filter((p: ProposalData) => {
    const statusMatches = statusFilter === 'All' || p.status === statusFilter
    const chainMatches = chainFilter === 'All' || p.chain.includes(chainFilter)
    return statusMatches && chainMatches
  })

  const visibleProposals = filteredProposals.slice(0, visibleCount) as ProposalData[]
  const hasMore = visibleCount < filteredProposals.length

  const isLoading = votesLoading && proposalIds.length > 0

  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'Active':
        return {
          color: 'text-primary',
          bgColor: 'bg-primary/10',
          borderColor: 'border-primary/20',
          glowColor: 'shadow-[0_0_30px_rgba(125,211,252,0.25)]',
          buttonClass:
            'bg-primary text-slate-950 shadow-[0_0_15px_rgba(125,211,252,0.4)] hover:brightness-110',
          indicatorColor: 'bg-primary',
        }
      case 'Executed':
      case 'Succeeded':
        return {
          color: 'text-emerald-400',
          bgColor: 'bg-emerald-400/10',
          borderColor: 'border-emerald-400/20',
          glowColor: 'shadow-[0_0_30px_rgba(52,211,153,0.15)]',
          buttonClass: 'border-slate-700 text-slate-500 hover:bg-slate-800',
          indicatorColor: 'bg-emerald-400',
        }
      case 'Executed on Hub':
        return {
          color: 'text-amber-400',
          bgColor: 'bg-amber-400/10',
          borderColor: 'border-amber-400/20',
          glowColor: 'shadow-[0_0_30px_rgba(251,191,36,0.15)]',
          buttonClass: 'border-slate-700 text-slate-500 hover:bg-slate-800',
          indicatorColor: 'bg-amber-400',
        }
      case 'Queued':
        return {
          color: 'text-tertiary',
          bgColor: 'bg-tertiary/10',
          borderColor: 'border-tertiary/20',
          glowColor: 'shadow-[0_0_30px_rgba(200,160,240,0.25)]',
          buttonClass:
            'border-tertiary/30 text-tertiary hover:bg-tertiary/10 shadow-[0_0_15px_rgba(200,160,240,0.2)]',
          indicatorColor: 'bg-tertiary',
        }
      case 'Defeated':
      case 'Canceled':
        return {
          color: 'text-error',
          bgColor: 'bg-error/10',
          borderColor: 'border-error/20',
          glowColor: 'shadow-[0_0_30px_rgba(255,107,107,0.15)]',
          buttonClass: 'border-slate-700 text-slate-500 hover:bg-slate-800',
          indicatorColor: 'bg-error',
        }
      default:
        return {
          color: 'text-slate-400',
          bgColor: 'bg-slate-400/10',
          borderColor: 'border-slate-600/20',
          glowColor: 'shadow-none',
          buttonClass: 'border-slate-700 text-slate-500 hover:bg-slate-800',
          indicatorColor: 'bg-slate-400',
        }
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

      <div className="flex flex-col gap-4 mb-10">
        <div className="flex flex-wrap items-center gap-4">
          {/* Status Filters */}
          <div className="bg-slate-900/50 border border-sky-400/10 p-1 rounded-xl flex items-center overflow-x-auto no-scrollbar">
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
                  setStatusFilter(status)
                  setVisibleCount(6)
                }}
                className={`px-5 py-2 rounded-lg font-bold text-xs uppercase tracking-wider transition-all whitespace-nowrap ${
                  statusFilter === status
                    ? 'bg-sky-400 text-slate-950 px-5'
                    : 'text-sky-300/60 hover:text-sky-300'
                }`}
              >
                {status}
              </button>
            ))}
          </div>

          {/* Chain Filters */}
          <div className="bg-slate-900/50 border border-sky-400/10 p-1 rounded-xl flex items-center overflow-x-auto no-scrollbar max-w-full">
            {(['All', 'Mainnet', 'Base', 'Arbitrum', 'Sonic', 'Hyperliquid'] as FilterChain[]).map(
              (chain) => (
                <button
                  key={chain}
                  onClick={() => {
                    setChainFilter(chain)
                    setVisibleCount(6)
                  }}
                  className={`px-5 py-2 rounded-lg font-bold text-xs uppercase tracking-wider whitespace-nowrap transition-all ${
                    chainFilter === chain
                      ? 'bg-sky-400/10 text-sky-300 px-5'
                      : 'text-sky-300/60 hover:text-sky-300'
                  }`}
                >
                  {chain === 'All' ? 'All Chains' : chain}
                </button>
              ),
            )}
          </div>
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

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {visibleProposals.map((proposal: ProposalData) => {
          const chainMetadata = CHAIN_METADATA[proposal.chain] || CHAIN_METADATA['Multi-Chain']
          const statusConfig = getStatusConfig(proposal.status)

          return (
            <div
              key={proposal.id}
              className={`glass-panel hover:glass-panel-elevated transition-all p-6 rounded-2xl flex flex-col border-t-2 ${chainMetadata.borderColor} ${statusConfig.glowColor} group h-full relative overflow-hidden`}
            >
              {/* Status Highlight / Partial Frame */}
              <div
                className={`absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-[30%] rounded-r-full group-hover:h-[40%] transition-all ${statusConfig.indicatorColor}`}
              />
              <div className="flex justify-between items-start mb-4">
                <div className="flex flex-col">
                  <span
                    className={`text-[10px] font-black ${chainMetadata.color} tracking-widest uppercase mb-1`}
                  >
                    {proposal.displayId || proposal.id.slice(0, 8)}
                  </span>
                  <div
                    className={`flex items-center gap-2 px-2 py-0.5 rounded-md ${statusConfig.bgColor} border ${statusConfig.borderColor}`}
                  >
                    {proposal.status === 'Active' && (
                      <span className="w-1.5 h-1.5 rounded-full bg-primary animate-pulse"></span>
                    )}
                    <span className={`text-[10px] font-bold uppercase ${statusConfig.color}`}>
                      {proposal.status}
                    </span>
                  </div>
                </div>
                <div className="flex items-center gap-2 bg-slate-900/80 px-3 py-1.5 rounded-full border border-sky-400/10">
                  <span className={`material-symbols-outlined ${chainMetadata.color} text-sm`}>
                    {chainMetadata.icon}
                  </span>
                  <span className="text-[10px] font-bold text-sky-100 uppercase tracking-tighter">
                    {proposal.chain}
                  </span>
                </div>
              </div>

              <h3 className="text-lg font-bold text-on-surface group-hover:text-primary transition-colors leading-snug mb-3">
                {proposal.title}
              </h3>
              <p className="text-xs text-on-surface-variant line-clamp-3 mb-6 leading-relaxed">
                {proposal.description}
              </p>

              {/* Voting Progress */}
              <div className="mt-auto space-y-4 mb-6">
                <div className="flex justify-between items-center text-[10px] font-bold uppercase tracking-wider">
                  <span className={proposal.quorumReached ? 'text-emerald-400' : 'text-sky-300'}>
                    {proposal.quorumReached ? 'Quorum reached' : 'Quorum progress'}
                  </span>
                  <span className="text-on-surface">{Math.round(proposal.quorumProgress)}%</span>
                </div>
                <div className="w-full">
                  <VoteBar
                    for={proposal.forPercent}
                    against={proposal.againstPercent}
                    abstain={proposal.abstainPercent}
                  />
                </div>
                <div className="flex justify-between items-center text-[10px] text-on-surface-variant">
                  <span>
                    {proposal.status === 'Active'
                      ? `Ends in ${proposal.timeRemaining}`
                      : proposal.status}
                  </span>
                  <span>{(proposal.forVotes + proposal.againstVotes).toLocaleString()} Votes</span>
                </div>
              </div>

              <div className="flex gap-2">
                <Link
                  href={
                    proposal.status === 'Active'
                      ? `/vote/${proposal.id}`
                      : `/proposal/${proposal.id}`
                  }
                  className={`flex-1 py-2 rounded-lg text-xs font-black uppercase tracking-wider hover:brightness-110 active:scale-95 transition-all text-center ${statusConfig.buttonClass}`}
                >
                  {proposal.status === 'Active' ? 'Vote' : 'Details'}
                </Link>
                <Link
                  href={`/proposal/${proposal.id}`}
                  className="px-3 py-2 rounded-lg border border-sky-400/20 text-sky-300 hover:bg-sky-400/5 transition-all flex items-center justify-center"
                >
                  <span className="material-symbols-outlined text-sm">visibility</span>
                </Link>
              </div>
            </div>
          )
        })}
      </div>

      {hasMore && (
        <div className="mt-12 flex justify-center">
          <button
            onClick={() => setVisibleCount((prev) => prev + 6)}
            className="group glass-panel-elevated px-10 py-3.5 rounded-full flex items-center gap-3 text-on-surface font-semibold hover:border-primary/50 transition-all active:scale-95 shadow-xl"
          >
            Load More Proposals
            <span className="material-symbols-outlined group-hover:translate-y-0.5 transition-transform">
              keyboard_arrow_down
            </span>
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
