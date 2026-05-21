'use client'

import type { InputHTMLAttributes, ReactNode } from 'react'

interface AmountInputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'children'> {
  suffix?: ReactNode
  meta?: ReactNode
  chips?: ReactNode
  className?: string
}

// Large mono numeric input with right-aligned suffix (token chip + symbol),
// a meta line below, and a chips row (e.g. max/half/quarter). Used by the
// Wizard's "Amount per trade" field.
export function AmountInput({ suffix, meta, chips, className = '', ...rest }: AmountInputProps) {
  return (
    <div>
      <div
        className={[
          'relative rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-[18px] py-[18px] focus-within:border-[var(--pink)] focus-within:shadow-[0_0_0_3px_var(--pink-soft)]',
          className,
        ].join(' ')}
      >
        <input
          {...rest}
          inputMode="decimal"
          className="w-full border-none bg-transparent font-mono text-[28px] tracking-[-0.02em] text-[var(--text)] outline-none [appearance:textfield] [&::-webkit-inner-spin-button]:m-0 [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:m-0 [&::-webkit-outer-spin-button]:appearance-none"
        />
        {suffix && (
          <span className="pointer-events-none absolute right-[18px] top-1/2 -translate-y-1/2 flex items-center gap-2 text-sm text-[var(--text-2)]">
            {suffix}
          </span>
        )}
      </div>
      {(meta || chips) && (
        <div className="mt-2 flex items-center justify-between">
          {meta && <span className="font-mono text-xs text-[var(--text-3)]">{meta}</span>}
          {chips && <div className="flex gap-1.5">{chips}</div>}
        </div>
      )}
    </div>
  )
}
