import type { InputHTMLAttributes, ReactNode } from 'react'

interface FieldProps {
  label: string
  hint?: ReactNode
  error?: ReactNode
  children: ReactNode
}

export function Field({ label, hint, error, children }: FieldProps) {
  return (
    <label className="flex flex-col gap-2 text-sm">
      <span className="text-[12px] uppercase tracking-[0.06em] text-[var(--text-3)]">{label}</span>
      {children}
      {error ? (
        <span className="text-xs text-[var(--danger)]">{error}</span>
      ) : hint ? (
        <span className="text-xs text-[var(--text-3)]">{hint}</span>
      ) : null}
    </label>
  )
}

type TextInputProps = InputHTMLAttributes<HTMLInputElement>

export function TextInput({ className, ...rest }: TextInputProps) {
  return (
    <input
      {...rest}
      className={[
        'w-full rounded-md border border-[var(--border)] bg-[var(--bg-elev)] px-3.5 py-3 text-sm text-[var(--text)] placeholder:text-[var(--text-4)] outline-none transition focus:border-[var(--pink)] focus:shadow-[0_0_0_3px_var(--pink-soft)]',
        className ?? '',
      ].join(' ')}
    />
  )
}
