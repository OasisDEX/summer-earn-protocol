'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

export function SideNavBar() {
  const pathname = usePathname()

  const isActive = (path: string) => {
    if (path === '/proposals')
      return pathname === '/proposals' || pathname === '/' || pathname.startsWith('/proposal/')
    return pathname.startsWith(path)
  }

  const navItems = [
    { path: '/proposals', label: 'Proposals', icon: 'ballot' },
    { path: '/treasury', label: 'Treasury', icon: 'account_balance_wallet' },
    { path: '/delegates', label: 'Delegates', icon: 'groups' },
    { path: '/create-proposal', label: 'Create Proposal', icon: 'add_circle' },
  ]

  return (
    <aside className="hidden lg:flex flex-col h-[calc(100vh-80px)] w-64 p-4 space-y-4 bg-console-surface border-r border-line sticky top-[80px]">
      <nav className="flex-1 space-y-1 font-sans text-xs font-medium">
        {navItems.map((item) => {
          const active = isActive(item.path)
          return (
            <Link
              key={item.path}
              href={item.path}
              className={`group relative flex items-center gap-3 px-3 py-2.5 rounded-lg active:scale-[0.98] transition-all ${
                active
                  ? 'bg-pink-bg text-brand-pink font-semibold'
                  : 'text-fg2 hover:bg-surface3 hover:text-fg'
              }`}
            >
              {active && (
                <div className="absolute left-0 top-1/4 bottom-1/4 w-1 bg-brand-gradient rounded-full" />
              )}
              <span
                className={`material-symbols-outlined text-lg ${
                  active ? 'text-brand-pink' : 'text-fg3 group-hover:text-fg'
                } transition-colors`}
              >
                {item.icon}
              </span>
              {item.label}
            </Link>
          )
        })}
      </nav>
    </aside>
  )
}
