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
    { path: '/cross-chain', label: 'Cross-Chain', icon: 'swap_calls' },
  ]

  return (
    <aside className="hidden lg:flex flex-col h-[calc(100vh-73px)] w-64 p-4 space-y-4 bg-slate-950/75 backdrop-blur-2xl border-r border-sky-400/10 sticky top-[73px]">
      <nav className="flex-1 space-y-1 font-sans text-sm font-medium">
        {navItems.map((item) => (
          <Link
            key={item.path}
            href={item.path}
            className={`flex items-center gap-3 px-3 py-2.5 rounded-lg active:scale-[0.98] duration-150 ${isActive(item.path) ? 'bg-sky-400/10 text-sky-300' : 'text-slate-400 hover:bg-sky-400/5 hover:translate-x-1 transition-all'}`}
          >
            <span className="material-symbols-outlined">{item.icon}</span>
            {item.label}
          </Link>
        ))}
      </nav>
      <div className="pt-4 border-t border-sky-400/10 space-y-1">
        <button className="flex items-center gap-3 px-3 py-2 text-slate-400 hover:bg-sky-400/5 transition-all text-xs w-full">
          <span className="material-symbols-outlined text-lg">settings</span>
          Settings
        </button>
        <button className="flex items-center gap-3 px-3 py-2 text-slate-400 hover:bg-sky-400/5 transition-all text-xs w-full">
          <span className="material-symbols-outlined text-lg">help</span>
          Support
        </button>
      </div>
    </aside>
  )
}
