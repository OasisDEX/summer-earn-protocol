'use client'

import { type ReactNode } from 'react'
import Link from 'next/link'

interface PageHeaderProps {
  title: ReactNode
  /** small uppercase category label above the title, e.g. "Governance" */
  eyebrow?: string
  description?: ReactNode
  /** right-aligned slot for ChainSelector / RefreshButton / actions */
  actions?: ReactNode
  backHref?: string
  className?: string
}

export function PageHeader({
  title,
  eyebrow,
  description,
  actions,
  backHref,
  className = '',
}: PageHeaderProps) {
  return (
    <div className={`mb-8 flex flex-wrap items-start justify-between gap-4 ${className}`}>
      <div className="min-w-0">
        {backHref && (
          <Link
            href={backHref}
            className="inline-flex items-center gap-1 text-sm text-on-surface-variant hover:text-on-surface transition-colors mb-2"
          >
            ← Back
          </Link>
        )}
        {eyebrow && (
          <p className="text-[11px] font-semibold uppercase tracking-widest text-primary/80 mb-1">
            {eyebrow}
          </p>
        )}
        <h1 className="text-2xl md:text-3xl font-headline font-bold text-on-surface tracking-tight">
          {title}
        </h1>
        {description && (
          <p className="mt-1.5 max-w-2xl text-sm text-on-surface-variant">{description}</p>
        )}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-3">{actions}</div>}
    </div>
  )
}

interface SectionHeaderProps {
  title: ReactNode
  description?: ReactNode
  actions?: ReactNode
  className?: string
}

export function SectionHeader({ title, description, actions, className = '' }: SectionHeaderProps) {
  return (
    <div className={`mb-4 flex flex-wrap items-center justify-between gap-3 ${className}`}>
      <div className="min-w-0">
        <h2 className="text-lg font-headline font-semibold text-on-surface">{title}</h2>
        {description && <p className="mt-0.5 text-sm text-on-surface-variant">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  )
}
