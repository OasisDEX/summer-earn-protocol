'use client'

import { type ComponentPropsWithoutRef } from 'react'

type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger'
type ButtonSize = 'sm' | 'md' | 'lg'

interface ButtonProps extends ComponentPropsWithoutRef<'button'> {
  variant?: ButtonVariant
  size?: ButtonSize
  fullWidth?: boolean
}

const VARIANTS: Record<ButtonVariant, string> = {
  primary: 'bg-primary text-on-primary hover:bg-primary-dim',
  secondary: 'bg-white/5 text-on-surface border border-white/10 hover:bg-white/10',
  outline: 'border border-outline-variant text-on-surface hover:border-outline hover:bg-white/5',
  ghost: 'text-on-surface-variant hover:text-on-surface hover:bg-white/5',
  danger: 'bg-error/15 text-error border border-error/30 hover:bg-error/25',
}

const SIZES: Record<ButtonSize, string> = {
  sm: 'px-2.5 py-1.5 text-xs rounded-lg',
  md: 'px-4 py-2 text-sm rounded-lg',
  lg: 'px-5 py-3 text-sm rounded-xl',
}

// Deliberately no default `type`: the native default (submit inside forms) is load-bearing.
export function Button({
  variant = 'primary',
  size = 'md',
  fullWidth = false,
  className = '',
  ...rest
}: ButtonProps) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 font-semibold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/50 disabled:opacity-40 disabled:cursor-not-allowed ${VARIANTS[variant]} ${SIZES[size]} ${fullWidth ? 'w-full' : ''} ${className}`}
      {...rest}
    />
  )
}
