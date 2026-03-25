'use client'

import React, { useState } from 'react'

import { Vote } from '@/types/governance'

interface RecentVotesProps {
  votes: Vote[]
  voterNames: Record<string, string>
}

export function RecentVotes({ votes, voterNames }: RecentVotesProps) {
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
    <section className="glass-panel rounded-xl overflow-hidden shadow-2xl border border-sky-400/10 transition-all duration-300">
      <div className="p-6 border-b border-sky-400/10 flex justify-between items-center bg-slate-900/40">
        <h3 className="text-lg font-semibold tracking-tight text-on-surface">Recent Votes</h3>
        <span className="text-xs font-medium text-on-surface-variant uppercase tracking-widest">
          Total: {votes.length} Addresses
        </span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-left">
          <thead className="bg-sky-400/5 text-xs text-on-surface-variant uppercase tracking-widest">
            <tr>
              <th className="px-6 py-5 font-semibold">Voter</th>
              <th className="px-6 py-5 font-semibold">Vote</th>
              <th className="px-6 py-5 font-semibold text-right">Votes</th>
              <th className="px-6 py-5 font-semibold text-right">Time</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-sky-400/5 text-sm">
            {displayedVotes.map((vote) => (
              <tr
                key={vote.id}
                className="hover:bg-sky-400/5 transition-colors group animate-fade-in"
              >
                <td className="px-6 py-4 flex items-center gap-3">
                  <div
                    className={`w-8 h-8 rounded-full shadow-lg ${
                      vote.support === 1
                        ? 'bg-gradient-to-tr from-sky-400 to-tertiary shadow-sky-400/10'
                        : vote.support === 0
                          ? 'bg-gradient-to-tr from-red-400 to-orange-500 shadow-red-400/10'
                          : 'bg-gradient-to-tr from-slate-400 to-slate-600'
                    }`}
                  ></div>
                  <span className="font-medium group-hover:text-sky-300 transition-colors">
                    {voterNames[vote.voter.toLowerCase()] ||
                      `${vote.voter.slice(0, 6)}...${vote.voter.slice(-4)}`}
                  </span>
                </td>
                <td className="px-6 py-4">
                  {vote.support === 1 ? (
                    <span className="text-emerald-400 flex items-center gap-1.5 font-medium">
                      <span
                        className="material-symbols-outlined text-[18px]"
                        style={{ fontVariationSettings: "'FILL' 1" }}
                      >
                        check_circle
                      </span>
                      For
                    </span>
                  ) : vote.support === 0 ? (
                    <span className="text-error flex items-center gap-1.5 font-medium">
                      <span
                        className="material-symbols-outlined text-[18px]"
                        style={{ fontVariationSettings: "'FILL' 1" }}
                      >
                        cancel
                      </span>
                      Against
                    </span>
                  ) : (
                    <span className="text-slate-400 flex items-center gap-1.5 font-medium">
                      <span
                        className="material-symbols-outlined text-[18px]"
                        style={{ fontVariationSettings: "'FILL' 1" }}
                      >
                        do_not_disturb_on
                      </span>
                      Abstain
                    </span>
                  )}
                </td>
                <td className="px-6 py-4 text-right font-mono text-on-surface">
                  {formatVotes(vote.votes)}
                </td>
                <td className="px-6 py-4 text-right text-on-surface-variant">
                  {getTimeAgo(vote.timestamp)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {votes.length > 5 && (
        <div className="p-6 text-center border-t border-sky-400/10 bg-slate-900/20">
          <button
            onClick={() => setShowAll(!showAll)}
            className="px-8 py-2.5 rounded-lg border border-sky-400/30 text-sky-300 text-sm font-bold uppercase tracking-widest hover:bg-sky-400/10 hover:border-sky-400/50 transition-all active:scale-95"
          >
            {showAll ? 'Show Less' : `View All ${votes.length} Votes`}
          </button>
        </div>
      )}
    </section>
  )
}
