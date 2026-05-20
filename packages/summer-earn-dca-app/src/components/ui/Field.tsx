import type { InputHTMLAttributes, ReactNode } from 'react'

interface FieldProps {
  label: string
  hint?: ReactNode
  error?: ReactNode
  children: ReactNode
}

export function Field({ label, hint, error, children }: FieldProps) {
  return (
    <label className="flex flex-col gap-1.5 text-sm">
      <span className="text-surface-200">{label}</span>
      {children}
      {error ? (
        <span className="text-xs text-danger">{error}</span>
      ) : hint ? (
        <span className="text-xs text-surface-400">{hint}</span>
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
        'rounded-md border border-surface-700 bg-surface-900 px-3 py-2 text-sm text-surface-50 placeholder:text-surface-500 focus:border-primary focus:outline-none',
        className ?? '',
      ].join(' ')}
    />
  )
}
