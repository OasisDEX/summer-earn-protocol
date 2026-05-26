'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

import type { Tab } from './adminTabs.config'

interface Props {
  tabs: Tab[]
}

export function AdminTabs({ tabs }: Props) {
  const pathname = usePathname() ?? ''
  return (
    <div className="mb-6 inline-flex gap-0.5 rounded-md border border-[var(--border-faint)] bg-[var(--surface)] p-[3px]">
      {tabs.map((tab) => {
        const on = pathname.startsWith(tab.href)
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={[
              'rounded-[7px] border-none px-3.5 py-[7px] text-[13px] transition',
              on
                ? 'bg-[var(--surface-hover)] text-[var(--text)] shadow-[inset_0_0_0_1px_var(--border)]'
                : 'bg-transparent text-[var(--text-2)] hover:text-[var(--text)]',
            ].join(' ')}
          >
            {tab.label}
          </Link>
        )
      })}
    </div>
  )
}
