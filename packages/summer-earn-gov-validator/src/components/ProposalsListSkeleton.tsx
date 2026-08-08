import React from 'react'

export function ProposalsListSkeleton() {
  return (
    <div className="flex flex-col gap-2.5 animate-pulse">
      <div className="mb-[18px]">
        <div className="h-7 w-48 bg-surface3 rounded mb-2" />
        <div className="h-4 w-96 bg-surface3 rounded" />
      </div>

      <div className="flex gap-4 items-center mb-4">
        <div className="flex gap-1.5">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="h-[30px] w-16 rounded-full bg-surface3" />
          ))}
        </div>
      </div>

      {[1, 2, 3].map((i) => (
        <div key={i} className="border border-line rounded-xl bg-console-surface p-[18px]">
          <div className="h-4 w-32 bg-surface3 rounded mb-4" />
          <div className="h-6 w-3/4 bg-surface3 rounded mb-2" />
          <div className="h-4 w-1/2 bg-surface3 rounded mb-4" />
          <div className="h-2 w-full bg-surface3 rounded" />
        </div>
      ))}
    </div>
  )
}
