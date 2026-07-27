'use client'

import { type ReactNode } from 'react'

type Padding = 'none' | 'sm' | 'md'

const PADDING: Record<Padding, string> = {
  none: '',
  sm: 'p-3',
  md: 'p-5',
}

interface GlassCardProps {
  children: ReactNode
  className?: string
  hover?: boolean
  padding?: Padding
}

export function GlassCard({
  children,
  className = '',
  hover = false,
  padding = 'md',
}: GlassCardProps) {
  return (
    <div
      className={`glass ${PADDING[padding]} rounded-xl ${hover ? 'transition-all hover:-translate-y-1 neon-glow' : ''} ${className}`}
    >
      {children}
    </div>
  )
}
