interface ProgressProps {
  value: number
  total: number
  showLabel?: boolean
  className?: string
}

export function Progress({ value, total, showLabel = true, className = '' }: ProgressProps) {
  const safeTotal = total > 0 ? total : 1
  const pct = Math.min(100, Math.max(0, (value / safeTotal) * 100))
  return (
    <span
      className={['inline-flex min-w-[92px] flex-col gap-1', className].join(' ')}
    >
      <span className="h-1 w-full overflow-hidden rounded-[2px] bg-[var(--surface-2)]">
        <span
          className="block h-full rounded-[2px] transition-[width] duration-300 ease-out"
          style={{
            width: `${pct}%`,
            background: 'linear-gradient(90deg, var(--pink), var(--pink-2))',
          }}
        />
      </span>
      {showLabel && (
        <span className="font-mono text-[11px] text-[var(--text-3)]">
          {value}/{total}
        </span>
      )}
    </span>
  )
}
