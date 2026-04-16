'use client'

import { useState } from 'react'
import Link from 'next/link'

import { VoteBar } from '@/components/VoteBar'
import { TransformedProposal } from '@/types/governance'
import { formatTimeRemaining, formatTimestamp } from '@/utils/timing'

interface ProposalsListProps {
  initialProposals: TransformedProposal[]
  detailPrefix?: string
}

type FilterStatus =
  | 'All'
  | 'Pending'
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
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    borderColor: 'border-primary/20',
    accentColor: 'bg-primary',
  },
  Base: {
    icon: 'change_history',
    color: 'text-secondary',
    bgColor: 'bg-secondary/10',
    borderColor: 'border-secondary/20',
    accentColor: 'bg-secondary',
  },
  Arbitrum: {
    icon: 'token',
    color: 'text-secondary',
    bgColor: 'bg-secondary/10',
    borderColor: 'border-secondary/20',
    accentColor: 'bg-secondary',
  },
  Sonic: {
    icon: 'waves',
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    borderColor: 'border-primary/20',
    accentColor: 'bg-primary',
  },
  Hyperliquid: {
    icon: 'bolt',
    color: 'text-tertiary',
    bgColor: 'bg-tertiary/10',
    borderColor: 'border-tertiary/20',
    accentColor: 'bg-tertiary',
  },
  'Multi-Chain': {
    icon: 'hub',
    color: 'text-primary',
    bgColor: 'bg-primary/10',
    borderColor: 'border-primary/20',
    accentColor: 'bg-primary',
  },
}

export function ProposalsList({
  initialProposals,
  detailPrefix = '/proposal',
}: ProposalsListProps) {
  const [statusFilter, setStatusFilter] = useState<FilterStatus>('All')
  const [chainFilter, setChainFilter] = useState<FilterChain>('All')
  const [visibleCount, setVisibleCount] = useState(6)

  const filteredProposals = initialProposals.filter((p) => {
    const statusMatches = statusFilter === 'All' || p.status === statusFilter
    const chainMatches = chainFilter === 'All' || p.chain.includes(chainFilter)
    return statusMatches && chainMatches
  })

  const visibleProposals = filteredProposals.slice(0, visibleCount)
  const hasMore = visibleCount < filteredProposals.length

  const getStatusConfig = (status: string) => {
    switch (status) {
      case 'Active':
        return {
          color: 'text-primary',
          bgColor: 'bg-primary/10',
          borderColor: 'border-primary/20',
          glowColor: 'shadow-[0_0_15px_rgba(255,135,185,0.4)]',
          buttonClass: 'bg-brand-gradient text-black font-black shadow-neon hover:brightness-110',
          indicatorColor: 'bg-primary',
        }
      case 'Executed':
      case 'Succeeded':
        return {
          color: 'text-emerald-400',
          bgColor: 'bg-emerald-400/10',
          borderColor: 'border-emerald-400/20',
          glowColor: 'shadow-[0_0_15px_rgba(52,211,153,0.3)]',
          buttonClass: 'border-outline/20 text-on-surface-variant hover:bg-surface-bright',
          indicatorColor: 'bg-emerald-400',
        }
      case 'Executed on Hub':
        return {
          color: 'text-amber-400',
          bgColor: 'bg-amber-400/10',
          borderColor: 'border-amber-400/20',
          glowColor: 'shadow-[0_0_15px_rgba(251,191,36,0.3)]',
          buttonClass: 'border-outline/20 text-on-surface-variant hover:bg-surface-bright',
          indicatorColor: 'bg-amber-400',
        }
      case 'Queued':
        return {
          color: 'text-secondary',
          bgColor: 'bg-secondary/10',
          borderColor: 'border-secondary/20',
          glowColor: 'shadow-[0_0_15px_rgba(184,132,255,0.3)]',
          buttonClass: 'border-secondary/30 text-secondary hover:bg-secondary/10 shadow-neon',
          indicatorColor: 'bg-secondary',
        }
      case 'Defeated':
      case 'Canceled':
        return {
          color: 'text-error',
          bgColor: 'bg-error/10',
          borderColor: 'border-error/20',
          glowColor: 'shadow-[0_0_15px_rgba(255,110,132,0.3)]',
          buttonClass: 'border-outline/20 text-on-surface-variant hover:bg-surface-bright',
          indicatorColor: 'bg-error',
        }
      case 'Pending':
        return {
          color: 'text-slate-400',
          bgColor: 'bg-slate-400/10',
          borderColor: 'border-slate-600/20',
          glowColor: 'shadow-none',
          buttonClass: 'border-slate-700 text-slate-500 hover:bg-slate-800',
          indicatorColor: 'bg-slate-400',
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
            Shape the future of Lazy Summer DAO. Cast your vote on active protocol upgrades and
            treasury allocations.
          </p>
        </div>
        <div className="flex gap-3">
          <Link
            href="/create-proposal"
            className="bg-brand-gradient text-black px-8 py-3 rounded-xl font-black text-xs uppercase tracking-[0.15em] flex items-center gap-3 hover:scale-[1.02] active:scale-95 transition-all shadow-neon-strong"
          >
            <span className="material-symbols-outlined text-[20px]">add_circle</span>
            New Proposal
          </Link>
        </div>
      </div>

      <div className="flex flex-col gap-6 mb-12">
        <div className="space-y-4">
          <span className="text-[10px] font-black text-on-surface-variant uppercase tracking-[0.2em] ml-1">
            Filter status
          </span>
          <div className="bg-surface-container-low/50 border border-outline-variant/10 p-1.5 rounded-2xl flex items-center overflow-x-auto no-scrollbar gap-1 shadow-inner max-w-fit">
            {(
              [
                'All',
                'Pending',
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
                className={`px-6 py-2.5 rounded-xl font-black text-[11px] uppercase tracking-wider transition-all active:scale-95 whitespace-nowrap ${
                  statusFilter === status
                    ? 'bg-brand-gradient text-black shadow-neon'
                    : 'text-on-surface-variant hover:text-on-surface hover:bg-surface-bright/50'
                }`}
              >
                {status}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-4">
          <span className="text-[10px] font-black text-on-surface-variant uppercase tracking-[0.2em] ml-1">
            Network
          </span>
          <div className="bg-surface-container-low/50 border border-outline-variant/10 p-1.5 rounded-2xl flex items-center overflow-x-auto no-scrollbar gap-1 shadow-inner max-w-fit">
            {(['All', 'Ethereum', 'Base', 'Arbitrum', 'Sonic', 'Hyperliquid'] as FilterChain[]).map(
              (chain) => (
                <button
                  key={chain}
                  onClick={() => {
                    setChainFilter(chain)
                    setVisibleCount(6)
                  }}
                  className={`px-6 py-2.5 rounded-xl font-black text-[11px] uppercase tracking-wider whitespace-nowrap transition-all active:scale-95 ${
                    chainFilter === chain
                      ? 'bg-secondary text-black shadow-neon'
                      : 'text-on-surface-variant hover:text-on-surface hover:bg-surface-bright/50'
                  }`}
                >
                  {chain === 'All' ? 'All Networks' : chain}
                </button>
              ),
            )}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {visibleProposals.map((proposal) => {
          const chainMetadata = CHAIN_METADATA[proposal.chain] || CHAIN_METADATA['Multi-Chain']
          const statusConfig = getStatusConfig(proposal.status)

          return (
            <div
              key={proposal.id}
              className={`glass-panel hover:glass-panel-elevated transition-all p-6 rounded-2xl flex flex-col border-t-2 ${chainMetadata.borderColor} ${statusConfig.glowColor} group h-full relative overflow-hidden`}
            >
              {/* Status Highlight / Partial Frame */}
              <div
                className={`absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-[30%] rounded-r-full group-hover:h-[40%] transition-all `}
              />
              <div className="flex justify-between items-start mb-4">
                <div className="flex flex-col">
                  <div className="flex items-center gap-2 mb-1">
                    <span
                      className={`text-[10px] font-black ${chainMetadata.color} tracking-widest uppercase`}
                    >
                      {proposal.displayId || proposal.id.slice(0, 8)}
                    </span>
                    <span className="text-[10px] text-on-surface-variant font-medium opacity-60">
                      • {formatTimestamp(proposal.createdAt)}
                    </span>
                  </div>
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
                <div className="flex items-center gap-2 bg-surface-container px-3 py-1.5 rounded-full border border-outline-variant/20 shadow-inner">
                  <span className={`material-symbols-outlined ${chainMetadata.color} text-sm`}>
                    {chainMetadata.icon}
                  </span>
                  <span className="text-[10px] font-black text-on-surface uppercase tracking-tight">
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
                <div className="flex justify-between items-center text-[10px] font-black uppercase tracking-[0.2em]">
                  <span className={proposal.quorumReached ? 'text-emerald-400' : 'text-primary'}>
                    {proposal.quorumReached ? 'Quorum achieved' : 'Quorum goal'}
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
                <div className="flex justify-between items-center text-[10px] text-on-surface-variant font-bold tracking-tight">
                  <div className="flex items-center gap-1.5 opacity-80 uppercase tracking-widest text-[9px]">
                    <span className="material-symbols-outlined text-[14px]">schedule</span>
                    <span>
                      {proposal.status === 'Active'
                        ? `Ends in ${formatTimeRemaining(proposal.timeRemaining)}`
                        : proposal.status === 'Pending'
                          ? `Starts in ${formatTimeRemaining(proposal.timeRemaining)}`
                          : proposal.status === 'Queued'
                            ? `Executable @ ${formatTimestamp(proposal.eta)}`
                            : proposal.status}
                    </span>
                  </div>
                  <span>{(proposal.forVotes + proposal.againstVotes).toLocaleString()} Votes</span>
                </div>
              </div>

              <Link
                href={`${detailPrefix}/${proposal.id}`}
                className={`w-full py-2.5 rounded-lg text-xs font-black uppercase tracking-wider hover:brightness-110 active:scale-95 transition-all flex items-center justify-center gap-2 ${statusConfig.buttonClass}`}
              >
                <span className="material-symbols-outlined text-sm">
                  {proposal.status === 'Active' ? 'how_to_vote' : 'visibility'}
                </span>
                {proposal.status === 'Active' ? 'Vote & Details' : 'View Details'}
              </Link>
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
