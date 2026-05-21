'use client'

import type { ReactNode } from 'react'
import Link from 'next/link'

export interface Crumb {
  href?: string
  label: string
}

interface TopbarProps {
  crumbs: Crumb[]
  actions?: ReactNode
}

export function Topbar({ crumbs, actions }: TopbarProps) {
  return (
    <div
      className="sticky top-0 z-[5] flex items-center justify-between px-9 py-[18px] backdrop-blur-[8px]"
      style={{
        background: 'linear-gradient(to bottom, var(--bg), rgba(8,8,12,0))',
      }}
    >
      <div className="flex items-center gap-2.5 text-[13px] text-[var(--text-3)]">
        {crumbs.map((crumb, idx) => {
          const isLast = idx === crumbs.length - 1
          return (
            <span key={`${crumb.label}-${idx}`} className="flex items-center gap-2.5">
              {crumb.href && !isLast ? (
                <Link
                  href={crumb.href}
                  className="text-[var(--text-3)] no-underline transition hover:text-[var(--text)]"
                >
                  {crumb.label}
                </Link>
              ) : (
                <span className={isLast ? 'text-[var(--text)]' : undefined}>{crumb.label}</span>
              )}
              {!isLast && <span aria-hidden>›</span>}
            </span>
          )
        })}
      </div>
      <div className="flex items-center gap-2.5">{actions}</div>
    </div>
  )
}
