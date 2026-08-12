'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

import { ConnectButton } from './ConnectButton'
import { DarkModeToggle } from './DarkModeToggle'

export function TopNavBar() {
  const pathname = usePathname()

  const tabs = [
    { label: 'Proposals', href: '/proposals' },
    { label: 'Treasury', href: '/treasury' },
    { label: 'Delegates', href: '/delegates' },
    { label: 'Create proposal', href: '/create-proposal' },
  ]

  const isActive = (href: string) => {
    if (href === '/proposals')
      return pathname === '/proposals' || pathname === '/' || pathname.startsWith('/proposal/')
    return pathname.startsWith(href)
  }

  return (
    <header className="sticky top-0 z-20 bg-console-surface border-b border-line">
      <div className="max-w-[1240px] mx-auto px-5 py-2.5 flex items-center justify-between flex-wrap gap-4">
        <Link href="/proposals" className="flex items-center gap-2.5 mr-auto group">
          <div className="w-6 h-6 rounded-full bg-brand-gradient flex-shrink-0" />
          <span className="text-[15px] font-semibold tracking-tight text-fg group-hover:text-brand-pink transition-colors">
            Lazy Summer DAO
          </span>
        </Link>

        <div className="flex items-center gap-3">
          <DarkModeToggle />
          <Link
            href="/create-proposal"
            className="h-8 px-3.5 rounded-lg border border-line2 bg-surface3 text-fg text-xs font-medium hover:bg-surface2 transition-colors flex items-center whitespace-nowrap"
          >
            New proposal
          </Link>
          <ConnectButton />
        </div>
      </div>

      <div className="max-w-[1240px] mx-auto px-5 flex gap-0.5 overflow-x-auto no-scrollbar">
        {tabs.map((tab) => {
          const active = isActive(tab.href)
          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={`px-3.5 py-2.5 text-xs border-b-2 transition-colors whitespace-nowrap ${
                active
                  ? 'border-brand-pink text-fg font-semibold'
                  : 'border-transparent text-fg2 hover:text-fg font-normal'
              }`}
            >
              {tab.label}
            </Link>
          )
        })}
      </div>
    </header>
  )
}
