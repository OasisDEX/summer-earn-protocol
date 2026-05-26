import type { ReactNode } from 'react'

interface StatProps {
  label: string
  value: ReactNode
  sub?: ReactNode
  trend?: 'up' | 'down'
  children?: ReactNode
}

// KPI tile. `children` renders a Sparkline (or anything) under the value.
export function Stat({ label, value, sub, trend, children }: StatProps) {
  return (
    <div className="relative overflow-hidden rounded-lg border border-[var(--border-faint)] bg-[var(--surface)] p-[22px]">
      <div className="text-[12px] uppercase tracking-[0.06em] text-[var(--text-3)]">{label}</div>
      <div className="mt-3 font-mono text-[30px] font-medium leading-tight tracking-[-0.02em] text-[var(--text)]">
        {value}
      </div>
      {sub && (
        <div
          className={[
            'mt-1.5 font-mono text-xs',
            trend === 'up'
              ? 'text-[var(--success)]'
              : trend === 'down'
                ? 'text-[var(--danger)]'
                : 'text-[var(--text-3)]',
          ].join(' ')}
        >
          {sub}
        </div>
      )}
      {children && <div className="mt-4">{children}</div>}
    </div>
  )
}
