'use client'

interface VoteBarProps {
  for: number
  against: number
  abstain: number
}

export function VoteBar({ for: forVotes, against, abstain }: VoteBarProps) {
  return (
    <div className="space-y-6">
      <div className="space-y-2">
        <div className="flex h-3 w-full rounded-full overflow-hidden bg-slate-800">
          <div
            className="bg-emerald-400 h-full shadow-[0_0_10px_rgba(52,211,153,0.3)]"
            style={{ width: `${forVotes}%` }}
          ></div>
          <div
            className="bg-error h-full shadow-[0_0_10px_rgba(255,107,107,0.3)]"
            style={{ width: `${against}%` }}
          ></div>
          <div className="bg-slate-500 h-full" style={{ width: `${abstain}%` }}></div>
        </div>
        <div className="flex justify-between text-[10px] uppercase tracking-widest font-bold">
          <span className="text-emerald-400">For {forVotes}%</span>
          <span className="text-error">Against {against}%</span>
          <span className="text-slate-400">Abstain {abstain}%</span>
        </div>
      </div>
    </div>
  )
}
