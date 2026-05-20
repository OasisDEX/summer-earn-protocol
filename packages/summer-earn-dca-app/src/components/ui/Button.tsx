import type { ButtonHTMLAttributes } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  loading?: boolean
}

const STYLES: Record<Variant, string> = {
  primary:
    'bg-primary text-surface-900 hover:bg-primary-400 disabled:bg-surface-700 disabled:text-surface-400',
  secondary:
    'bg-surface-700 text-surface-100 hover:bg-surface-600 disabled:bg-surface-800 disabled:text-surface-500',
  ghost: 'bg-transparent text-surface-100 hover:bg-surface-700/60',
  danger:
    'bg-danger/80 text-white hover:bg-danger disabled:bg-surface-700 disabled:text-surface-400',
}

export function Button({
  variant = 'primary',
  loading,
  className,
  children,
  disabled,
  ...rest
}: ButtonProps) {
  return (
    <button
      {...rest}
      disabled={disabled || loading}
      className={[
        'inline-flex items-center justify-center gap-2 rounded-md px-4 py-2 text-sm font-medium transition disabled:cursor-not-allowed',
        STYLES[variant],
        className ?? '',
      ].join(' ')}
    >
      {loading && (
        <span className="h-3 w-3 animate-spin rounded-full border-2 border-current border-t-transparent" />
      )}
      {children}
    </button>
  )
}
