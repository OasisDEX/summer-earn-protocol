'use client'

import React, { useState } from 'react'
import { Bird } from 'lucide-react'

import { Vote, VoterMetadata } from '@/types/governance'

interface RecentVotesProps {
  votes: Vote[]
  voterMetadata: Record<string, VoterMetadata>
}

export function RecentVotes({ votes, voterMetadata }: RecentVotesProps) {
  const [showAll, setShowAll] = useState(false)

  const formatVotes = (votes: string) => {
    const value = parseFloat(votes) / 1e18
    if (value >= 1000000) return `${(value / 1000000).toFixed(1)}M SUMR`
    if (value >= 1000) return `${(value / 1000).toFixed(1)}K SUMR`
    return `${value.toFixed(1)} SUMR`
  }

  const getTimeAgo = (timestamp: string) => {
    const seconds = Math.floor(Date.now() / 1000) - parseInt(timestamp)
    if (seconds < 60) return 'just now'
    const minutes = Math.floor(seconds / 60)
    if (minutes < 60) return `${minutes}m ago`
    const hours = Math.floor(minutes / 60)
    if (hours < 24) return `${hours}h ago`
    return `${Math.floor(hours / 24)}d ago`
  }

  const displayedVotes = showAll ? votes : votes.slice(0, 5)

  if (votes.length === 0) return null

  return (
    <section className="border border-line rounded-xl bg-console-surface overflow-hidden">
      <div className="px-4 py-3.5 border-b border-line flex justify-between items-center">
        <h3 className="text-[13px] font-semibold text-fg">Recent votes</h3>
        <span className="text-[10px] font-semibold text-fg3 uppercase tracking-[0.07em]">
          Total: {votes.length}
        </span>
      </div>

      <div className="divide-y divide-line">
        {displayedVotes.map((vote) => {
          const metadata = voterMetadata[vote.voter.toLowerCase()]
          const isFor = vote.support === 1
          const isAgainst = vote.support === 0

          return (
            <div key={vote.id} className="px-4 py-3 hover:bg-surface2 transition-colors">
              <div className="flex items-center justify-between gap-2.5">
                <div className="flex items-center gap-2.5 min-w-0">
                  {metadata?.picture ? (
                    <div className="w-8 h-8 shrink-0 rounded-full overflow-hidden border border-line">
                      <img
                        src={metadata.picture}
                        alt={metadata.name}
                        className="w-full h-full object-cover"
                      />
                    </div>
                  ) : (
                    <div
                      className={`w-8 h-8 shrink-0 rounded-full flex items-center justify-center text-[10px] font-semibold border border-line ${
                        isFor
                          ? 'bg-ok-bg text-ok'
                          : isAgainst
                            ? 'bg-crit-bg text-crit'
                            : 'bg-surface3 text-fg3'
                      }`}
                    >
                      {metadata?.name?.slice(0, 2).toUpperCase() || '??'}
                    </div>
                  )}

                  <div className="flex flex-col min-w-0">
                    <div className="flex items-center gap-1.5 min-w-0">
                      <span className="text-[12px] font-semibold text-fg truncate max-w-[120px]">
                        {metadata?.name || `${vote.voter.slice(0, 6)}...${vote.voter.slice(-4)}`}
                      </span>
                      {metadata?.twitter && (
                        <a
                          href={`https://twitter.com/${metadata.twitter}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-fg3 hover:text-brand-pink transition-colors shrink-0"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <Bird className="w-3 h-3" />
                        </a>
                      )}
                    </div>
                    <span
                      className={`text-[9px] font-bold uppercase tracking-[0.15em] ${
                        isFor ? 'text-ok' : isAgainst ? 'text-crit' : 'text-fg3'
                      }`}
                    >
                      {isFor ? 'For' : isAgainst ? 'Against' : 'Abstain'}
                    </span>
                  </div>
                </div>

                <div className="text-right shrink-0">
                  <span className="block font-mono text-xs text-fg">{formatVotes(vote.votes)}</span>
                  <span className="block font-mono text-[10px] text-fg3">
                    {getTimeAgo(vote.timestamp)}
                  </span>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {votes.length > 5 && (
        <button
          onClick={() => setShowAll(!showAll)}
          className="w-full py-2.5 border-t border-line text-brand-pink text-xs font-semibold hover:bg-surface2 transition-colors"
        >
          {showAll ? 'Collapse' : `View all ${votes.length} votes`}
        </button>
      )}
    </section>
  )
}
