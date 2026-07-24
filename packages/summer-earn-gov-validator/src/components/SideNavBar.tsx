'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

export function SideNavBar() {
  const pathname = usePathname()

  const isActive = (path: string) => pathname.startsWith(path)

  const navItems = [
    { path: '/proposals', label: 'Proposals', icon: 'ballot' },
    { path: '/treasury', label: 'Treasury', icon: 'account_balance_wallet' },
    { path: '/delegates', label: 'Delegates', icon: 'groups' },
  ]

  return (
    <aside className="hidden lg:flex flex-col h-[calc(100vh-73px)] w-64 p-4 space-y-4 bg-surface-dim/75 backdrop-blur-2xl border-r border-outline/20 sticky top-[73px]">
      <nav className="flex-1 space-y-1 font-sans text-sm font-medium">
        {navItems.map((item) => (
          <Link
            key={item.path}
            href={item.path}
            className={`group relative flex items-center gap-3 px-3 py-2.5 rounded-lg active:scale-[0.98] duration-150 transition-all ${
              isActive(item.path)
                ? 'bg-primary/10 text-primary'
                : 'text-on-surface-variant hover:bg-surface-bright/50 hover:text-on-surface hover:translate-x-1'
            }`}
          >
            {isActive(item.path) && (
              <div className="absolute left-0 top-1/4 bottom-1/4 w-1 bg-brand-gradient rounded-full" />
            )}
            <span
              className={`material-symbols-outlined ${isActive(item.path) ? 'text-primary' : 'text-on-surface-variant/70 group-hover:text-primary'} transition-colors`}
            >
              {item.icon}
            </span>
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  )
}
