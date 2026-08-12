'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

export function BottomNavBar() {
  const pathname = usePathname()

  const isActive = (path: string) => {
    if (path === '/proposals')
      return pathname === '/proposals' || pathname === '/' || pathname.startsWith('/proposal/')
    return pathname.startsWith(path)
  }

  const navItems = [
    { id: 'proposals', path: '/proposals', label: 'Proposals', icon: 'ballot' },
    { id: 'treasury', path: '/treasury', label: 'Treasury', icon: 'account_balance_wallet' },
    { id: 'delegates', path: '/delegates', label: 'Delegates', icon: 'groups' },
    { id: 'create', path: '/create-proposal', label: 'New SIP', icon: 'add_circle' },
  ]

  return (
    <nav className="lg:hidden fixed bottom-0 left-0 w-full z-50 flex justify-around items-center px-4 py-2.5 pb-safe bg-console-surface/90 backdrop-blur-md border-t border-line">
      {navItems.map((item) => {
        const active = isActive(item.path)
        return (
          <Link
            key={item.id}
            href={item.path}
            className={`flex flex-col items-center justify-center tap-highlight-transparent transition-transform duration-100 active:scale-95 ${
              active ? 'text-brand-pink' : 'text-fg3 hover:text-fg2'
            }`}
          >
            <span className="material-symbols-outlined text-xl">{item.icon}</span>
            <span className="text-[10px] font-medium uppercase tracking-wider mt-0.5">
              {item.label}
            </span>
          </Link>
        )
      })}
    </nav>
  )
}

export function CreateProposalFAB() {
  return (
    <Link
      href="/create-proposal"
      className="fixed bottom-20 right-5 w-12 h-12 rounded-full bg-brand-gradient text-white shadow-lg flex items-center justify-center hover:scale-105 active:scale-95 transition-all z-40 lg:hidden"
    >
      <span className="material-symbols-outlined text-xl">add</span>
    </Link>
  )
}
