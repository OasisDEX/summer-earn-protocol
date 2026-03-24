'use client'

interface VoteBarProps {
  for: number
  against: number
  abstain: number
}

export function VoteBar({ for: forVotes, against, abstain }: VoteBarProps) {
  return (
    <div className="space-y-4">
      <div className="space-y-2">
        <div className="flex h-2 w-full rounded-full overflow-hidden bg-slate-800 shadow-inner">
          <div
            className="bg-emerald-400 h-full shadow-[0_0_15px_rgba(52,211,153,0.5)] transition-all duration-700"
            style={{ width: `${forVotes}%` }}
          ></div>
          <div
            className="bg-error h-full shadow-[0_0_15px_rgba(255,107,107,0.5)] transition-all duration-700"
            style={{ width: `${against}%` }}
          ></div>
          <div
            className="bg-slate-500 h-full transition-all duration-700"
            style={{ width: `${abstain}%` }}
          ></div>
        </div>
        <div className="flex justify-between text-[10px] uppercase tracking-widest font-black">
          <div className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
            <span className="text-emerald-400">For {forVotes}%</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-error"></span>
            <span className="text-error">Against {against}%</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-slate-400">Abstain {abstain}%</span>
          </div>
        </div>
      </div>
    </div>
  )
}
