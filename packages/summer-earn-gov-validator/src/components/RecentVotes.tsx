'use client'

import React, { useState } from 'react'
import { Twitter } from 'lucide-react'

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
    <section className="glass-panel-elevated rounded-xl overflow-hidden shadow-[0_20px_50px_rgba(0,0,0,0.3)] border border-white/5 transition-all duration-300">
      <div className="p-5 border-b border-white/5 flex justify-between items-center bg-white/5">
        <h3 className="text-sm font-bold uppercase tracking-widest text-on-surface opacity-80">
          Recent Votes
        </h3>
        <span className="text-[10px] font-bold text-on-surface-variant uppercase tracking-widest opacity-60">
          Total: {votes.length}
        </span>
      </div>

      <div className="divide-y divide-white/5">
        {displayedVotes.map((vote) => {
          const metadata = voterMetadata[vote.voter.toLowerCase()]
          const isFor = vote.support === 1
          const isAgainst = vote.support === 0

          return (
            <div
              key={vote.id}
              className="px-5 py-4 hover:bg-white/[0.02] transition-colors group relative animate-fade-in"
            >
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-3">
                  <div className="relative isolate">
                    {metadata?.picture ? (
                      <div className="w-10 h-10 rounded-full overflow-hidden border border-white/10 shadow-inner group-hover:scale-105 transition-transform duration-300">
                        <img
                          src={metadata.picture}
                          alt={metadata.name}
                          className="w-full h-full object-cover"
                        />
                      </div>
                    ) : (
                      <div
                        className={`w-10 h-10 rounded-full flex items-center justify-center text-[10px] font-bold text-white border border-white/10 shadow-inner group-hover:scale-105 transition-transform duration-300 ${
                          isFor
                            ? 'bg-gradient-to-tr from-emerald-500/40 to-emerald-400/10'
                            : isAgainst
                              ? 'bg-gradient-to-tr from-error/40 to-error/10'
                              : 'bg-gradient-to-tr from-slate-500/40 to-slate-400/10'
                        }`}
                      >
                        {metadata?.name?.slice(0, 2).toUpperCase() || '??'}
                      </div>
                    )}
                    {/* Tiny support dot */}
                    <div
                      className={`absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-slate-950 shadow-sm flex items-center justify-center ${
                        isFor ? 'bg-emerald-400' : isAgainst ? 'bg-error' : 'bg-slate-400'
                      }`}
                    >
                      <span className="material-symbols-outlined text-[10px] text-black font-bold">
                        {isFor ? 'check' : isAgainst ? 'close' : 'remove'}
                      </span>
                    </div>
                  </div>

                  <div className="flex flex-col min-w-0">
                    <div className="flex items-center gap-1.5">
                      <span className="font-bold text-on-surface text-sm truncate max-w-[120px]">
                        {metadata?.name || `${vote.voter.slice(0, 6)}...${vote.voter.slice(-4)}`}
                      </span>
                      {metadata?.twitter && (
                        <a
                          href={`https://twitter.com/${metadata.twitter}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-white/20 hover:text-sky-400 transition-colors"
                          onClick={(e) => e.stopPropagation()}
                        >
                          <Twitter className="w-3 h-3" />
                        </a>
                      )}
                    </div>
                    <div className="flex items-center gap-1.5 mt-0.5">
                      <span
                        className={`text-[9px] font-black uppercase tracking-[0.2em] ${
                          isFor ? 'text-emerald-400' : isAgainst ? 'text-error' : 'text-slate-400'
                        }`}
                      >
                        {isFor ? 'FOR' : isAgainst ? 'AGAINST' : 'ABSTAIN'}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="text-right flex flex-col items-end">
                  <span className="text-sm font-mono font-bold text-on-surface">
                    {formatVotes(vote.votes)}
                  </span>
                  <span className="text-[10px] text-on-surface-variant opacity-50 uppercase tracking-tighter">
                    {getTimeAgo(vote.timestamp)}
                  </span>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {votes.length > 5 && (
        <div className="p-4 bg-white/5 border-t border-white/5">
          <button
            onClick={() => setShowAll(!showAll)}
            className="w-full py-2.5 rounded-lg border border-white/10 text-[10px] font-black uppercase tracking-[0.3em] text-on-surface-variant hover:bg-white/5 hover:text-on-surface transition-all active:scale-[0.98]"
          >
            {showAll ? 'Collapse' : `View All ${votes.length} Votes`}
          </button>
        </div>
      )}
    </section>
  )
}
