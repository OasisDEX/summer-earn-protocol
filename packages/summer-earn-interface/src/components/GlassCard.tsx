'use client'

import { type ReactNode } from 'react'

interface GlassCardProps {
  children: ReactNode
  className?: string
  hover?: boolean
}

export function GlassCard({ children, className = '', hover = false }: GlassCardProps) {
  return (
    <div
      className={`glass p-5 rounded-xl ${hover ? 'transition-all hover:-translate-y-1 neon-glow' : ''} ${className}`}
    >
      {children}
    </div>
  )
}
