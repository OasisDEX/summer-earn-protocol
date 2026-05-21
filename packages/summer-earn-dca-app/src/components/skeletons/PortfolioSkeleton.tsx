const SHIMMER = 'animate-pulse rounded-md bg-[var(--surface)] border border-[var(--border-faint)]'

export function PortfolioSkeleton() {
  return (
    <div className="page" aria-busy="true" aria-live="polite">
      <header className="mb-7 flex flex-wrap items-end justify-between gap-3">
        <div>
          <div className={`${SHIMMER} h-9 w-44`} />
          <div className={`${SHIMMER} mt-2 h-3 w-56`} />
        </div>
      </header>

      <div className="grid grid-cols-1 gap-3.5 md:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className={`${SHIMMER} h-[112px]`} />
        ))}
      </div>

      <div className="mt-8 space-y-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className={`${SHIMMER} h-24`} />
        ))}
      </div>
    </div>
  )
}
