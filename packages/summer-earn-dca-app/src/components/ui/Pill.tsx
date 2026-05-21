import type { HTMLAttributes } from 'react'

export type PillVariant = 'active' | 'paused' | 'completed' | 'cancelled' | 'neutral'

interface PillProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: PillVariant
  dot?: boolean
}

const VARIANTS: Record<PillVariant, string> = {
  active: 'text-[var(--lime)] bg-[rgba(197,242,110,0.10)]',
  paused: 'text-[var(--warning)] bg-[rgba(255,179,92,0.10)]',
  completed: 'text-[var(--text-2)] bg-[var(--surface-2)]',
  cancelled: 'text-[var(--danger)] bg-[rgba(255,92,122,0.10)]',
  neutral: 'text-[var(--text-2)] bg-[var(--surface-2)]',
}

export function Pill({ variant = 'neutral', dot = true, children, className, ...rest }: PillProps) {
  return (
    <span
      {...rest}
      className={[
        'inline-flex items-center gap-1.5 whitespace-nowrap rounded-pill px-2.5 py-1 text-[11px] font-medium tracking-[0.01em]',
        VARIANTS[variant],
        className ?? '',
      ].join(' ')}
    >
      {dot && (
        <span
          aria-hidden
          className="inline-block h-1.5 w-1.5 rounded-full bg-current"
        />
      )}
      {children}
    </span>
  )
}
