'use client'

import { useState } from 'react'
import Link from 'next/link'

import { TransformedProposal } from '@/types/governance'
import { stripMarkdownForPreview } from '@/utils/text'
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

type FilterChain = 'All' | 'Ethereum' | 'Base' | 'Arbitrum' | 'Sonic' | 'Hyperliquid'

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

  const getStatusStyle = (status: string) => {
    switch (status) {
      case 'Active':
      case 'Executed':
        return { bg: 'var(--okBg)', fg: 'var(--ok)' }
      case 'Executed on Hub':
      case 'Queued':
        return { bg: 'var(--warnBg)', fg: 'var(--warn)' }
      case 'Defeated':
        return { bg: 'var(--critBg)', fg: 'var(--crit)' }
      case 'Pending':
        return { bg: 'var(--infoBg)', fg: 'var(--info)' }
      case 'Canceled':
      default:
        return { bg: 'var(--surface3)', fg: 'var(--fg3)' }
    }
  }

  return (
    <div>
      <div className="mb-[18px]">
        <h1 className="margin-0 text-[26px] font-semibold tracking-[-0.03em] text-fg">Proposals</h1>
        <p className="margin-top-[4px] text-fg2 text-xs">
          Proposals are created and voted on Base. Satellite chains are execute-only.
        </p>
      </div>

      <div className="flex gap-4 flex-wrap items-center mb-4">
        <div className="flex gap-1.5 flex-wrap">
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
          ).map((f) => {
            const isSelected = statusFilter === f
            return (
              <button
                key={f}
                onClick={() => {
                  setStatusFilter(f)
                  setVisibleCount(6)
                }}
                className={`h-[30px] px-[11px] rounded-full border text-xs font-medium cursor-pointer transition-colors ${
                  isSelected
                    ? 'border-brand-pink bg-pink-bg text-brand-pink'
                    : 'border-line2 bg-surface3 text-fg2 hover:text-fg'
                }`}
              >
                {f}
              </button>
            )
          })}
        </div>

        <select
          value={chainFilter}
          onChange={(e) => setChainFilter(e.target.value as FilterChain)}
          className="h-[30px] px-2.5 border border-line2 rounded-lg bg-field text-xs text-fg ml-auto font-mono"
        >
          <option value="All">All Networks</option>
          <option value="Ethereum">Ethereum</option>
          <option value="Base">Base</option>
          <option value="Arbitrum">Arbitrum</option>
          <option value="Sonic">Sonic</option>
          <option value="Hyperliquid">Hyperliquid</option>
        </select>
      </div>

      <div className="flex flex-col gap-2.5">
        {visibleProposals.map((p) => {
          const st = getStatusStyle(p.status)
          return (
            <article
              key={p.id}
              className="border border-line rounded-xl bg-console-surface overflow-hidden"
            >
              <div className="flex items-center gap-2.5 flex-wrap px-[18px] py-3 border-b border-line">
                <span className="font-mono text-xs font-semibold text-brand-pink">
                  {p.displayId || p.id.slice(0, 8)}
                </span>
                <span
                  className="px-2 py-0.5 rounded text-[10px] font-semibold tracking-wider uppercase"
                  style={{ background: st.bg, color: st.fg }}
                >
                  {p.status}
                </span>
                <span className="px-2 py-0.5 rounded text-[10px] font-semibold tracking-wider bg-surface3 text-fg2">
                  {p.chain}
                </span>
                <span className="ml-auto font-mono text-[11px] text-fg3">
                  {formatTimestamp(p.createdAt)}
                </span>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-[minmax(0,1.7fr)_minmax(0,1fr)] gap-6 p-[18px]">
                <div className="min-w-0">
                  <h2 className="m-0 mb-1.5 text-[17px] font-semibold tracking-tight text-fg">
                    {p.title}
                  </h2>
                  <p className="m-0 text-fg2 text-xs max-w-[62ch] line-clamp-3">
                    {stripMarkdownForPreview(p.description)}
                  </p>
                  <div className="flex gap-2.5 flex-wrap mt-3.5 items-center">
                    <Link
                      href={`${detailPrefix}/${p.id}`}
                      className="h-[32px] inline-flex items-center px-[14px] rounded-lg border border-line2 bg-surface3 text-fg text-xs font-semibold hover:bg-surface2 transition-colors"
                    >
                      View details
                    </Link>
                    <span className="font-mono text-xs text-fg3">
                      {p.status === 'Active'
                        ? `Ends in ${formatTimeRemaining(p.timeRemaining)}`
                        : p.status === 'Pending'
                          ? `Starts in ${formatTimeRemaining(p.timeRemaining)}`
                          : p.status === 'Queued'
                            ? `Executable @ ${formatTimestamp(p.eta)}`
                            : p.status}
                    </span>
                  </div>
                </div>

                <div className="min-w-0">
                  <div className="flex items-baseline justify-between mb-2">
                    <span className="text-[10px] font-semibold tracking-wider uppercase text-fg3">
                      Quorum
                    </span>
                    <span className="font-mono text-xs text-fg font-medium">
                      {Math.round(p.quorumProgress)}%
                    </span>
                  </div>
                  <div className="h-[6px] rounded-full bg-surface3 overflow-hidden mb-3.5">
                    <div
                      className="h-full rounded-full bg-brand-gradient transition-all"
                      style={{ width: `${Math.min(p.quorumProgress, 100)}%` }}
                    />
                  </div>

                  <div className="space-y-2">
                    <div>
                      <div className="flex justify-between text-[11px] mb-1">
                        <span className="text-fg2">For</span>
                        <span className="font-mono text-fg3">{Math.round(p.forPercent)}%</span>
                      </div>
                      <div className="h-[4px] rounded-full bg-surface3 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-ok"
                          style={{ width: `${p.forPercent}%` }}
                        />
                      </div>
                    </div>

                    <div>
                      <div className="flex justify-between text-[11px] mb-1">
                        <span className="text-fg2">Against</span>
                        <span className="font-mono text-fg3">{Math.round(p.againstPercent)}%</span>
                      </div>
                      <div className="h-[4px] rounded-full bg-surface3 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-crit"
                          style={{ width: `${p.againstPercent}%` }}
                        />
                      </div>
                    </div>

                    <div>
                      <div className="flex justify-between text-[11px] mb-1">
                        <span className="text-fg2">Abstain</span>
                        <span className="font-mono text-fg3">{Math.round(p.abstainPercent)}%</span>
                      </div>
                      <div className="h-[4px] rounded-full bg-surface3 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-fg3"
                          style={{ width: `${p.abstainPercent}%` }}
                        />
                      </div>
                    </div>
                  </div>

                  <div className="font-mono text-xs text-fg3 mt-2.5">
                    {(p.forVotes + p.againstVotes + p.abstainVotes).toLocaleString()} Votes
                  </div>
                </div>
              </div>
            </article>
          )
        })}
      </div>

      {hasMore && (
        <div className="flex justify-center mt-4">
          <button
            onClick={() => setVisibleCount((prev) => prev + 6)}
            className="h-[36px] px-5 rounded-full border border-line2 bg-surface3 text-fg2 text-xs font-medium cursor-pointer hover:text-fg hover:bg-surface2 transition-colors"
          >
            Load more proposals
          </button>
        </div>
      )}

      {filteredProposals.length === 0 && (
        <div className="text-center py-12 border border-line rounded-xl bg-console-surface">
          <p className="text-fg2 text-xs">No proposals found matching criteria.</p>
        </div>
      )}
    </div>
  )
}
