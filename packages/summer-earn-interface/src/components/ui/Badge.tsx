'use client'

import { type ComponentPropsWithoutRef } from 'react'

type BadgeTone = 'neutral' | 'primary' | 'success' | 'warning' | 'danger' | 'info'
type BadgeSize = 'sm' | 'md'

interface BadgeProps extends ComponentPropsWithoutRef<'span'> {
  tone?: BadgeTone
  size?: BadgeSize
}

const TONES: Record<BadgeTone, string> = {
  neutral: 'bg-white/5 text-on-surface-variant border-white/10',
  primary: 'bg-primary/15 text-primary border-primary/25',
  success: 'bg-success/15 text-success border-success/25',
  warning: 'bg-warning/15 text-warning border-warning/25',
  danger: 'bg-error/15 text-error border-error/25',
  info: 'bg-info/15 text-info border-info/25',
}

const SIZES: Record<BadgeSize, string> = {
  sm: 'px-1.5 py-0.5 text-[11px]',
  md: 'px-2.5 py-0.5 text-xs',
}

export function Badge({ tone = 'neutral', size = 'md', className = '', ...rest }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border font-medium whitespace-nowrap ${TONES[tone]} ${SIZES[size]} ${className}`}
      {...rest}
    />
  )
}
