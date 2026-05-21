const SHIMMER =
  'animate-pulse rounded-md bg-[var(--surface)] border border-[var(--border-faint)]'

export function StrategyDetailSkeleton() {
  return (
    <div className="page" aria-busy="true" aria-live="polite">
      <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
        <div>
          <div className={`${SHIMMER} h-8 w-72`} />
          <div className={`${SHIMMER} mt-2 h-3 w-40`} />
        </div>
        <div className={`${SHIMMER} h-9 w-44`} />
      </div>

      <div className={`${SHIMMER} h-[360px] w-full`} />

      <div className="mt-6 grid grid-cols-1 gap-3.5 md:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className={`${SHIMMER} h-[112px]`} />
        ))}
      </div>

      <div className={`${SHIMMER} mt-6 h-64 w-full`} />
    </div>
  )
}
