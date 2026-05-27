import type { ButtonHTMLAttributes } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'
type Size = 'sm' | 'md' | 'lg'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  loading?: boolean
}

const VARIANTS: Record<Variant, string> = {
  primary:
    'bg-[var(--pink)] text-[#1A0A12] font-semibold hover:bg-[var(--pink-2)] disabled:bg-[var(--surface-2)] disabled:text-[var(--text-4)]',
  secondary:
    'bg-[var(--surface)] text-[var(--text)] border border-[var(--border)] hover:bg-[var(--surface-hover)] hover:border-[var(--border-strong)]',
  ghost: 'bg-transparent text-[var(--text-2)] hover:text-[var(--text)] hover:bg-[var(--surface)]',
  danger:
    'bg-transparent text-[var(--danger)] border border-[rgba(255,92,122,0.3)] hover:bg-[rgba(255,92,122,0.08)] hover:border-[var(--danger)]',
}

const SIZES: Record<Size, string> = {
  sm: 'px-2.5 py-1.5 text-xs',
  md: 'px-4 py-2.5 text-sm',
  lg: 'px-5 py-3.5 text-[15px]',
}

export function Button({
  variant = 'primary',
  size = 'md',
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
        'inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium transition active:translate-y-[1px] disabled:cursor-not-allowed',
        'rounded-pill',
        SIZES[size],
        VARIANTS[variant],
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
