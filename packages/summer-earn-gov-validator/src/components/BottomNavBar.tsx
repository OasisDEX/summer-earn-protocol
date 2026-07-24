'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

export function BottomNavBar() {
  const pathname = usePathname()

  const isActive = (path: string) => pathname.startsWith(path)

  const navItems = [
    { id: 'home-proposals', path: '/proposals', label: 'Home', icon: 'home' },
    { id: 'treasury-main', path: '/treasury', label: 'Treasury', icon: 'account_balance' },
    { id: 'vote-proposals', path: '/proposals', label: 'Vote', icon: 'how_to_vote', filled: true },
    { id: 'delegates', path: '/delegates', label: 'Delegates', icon: 'groups' },
    { id: 'treasury-wallet', path: '/treasury', label: 'Wallet', icon: 'account_balance_wallet' },
  ]

  return (
    <nav className="lg:hidden fixed bottom-0 left-0 w-full z-50 flex justify-around items-center px-4 py-3 pb-safe bg-slate-950/80 backdrop-blur-lg border-t border-sky-400/20 shadow-2xl">
      {navItems.map((item) => (
        <Link
          key={item.id}
          href={item.path}
          className={`flex flex-col items-center justify-center tap-highlight-transparent transition-transform duration-100 active:scale-95 ${isActive(item.path) ? 'text-sky-300 bg-sky-400/10 rounded-xl px-3 py-1' : 'text-slate-500'}`}
        >
          <span
            className="material-symbols-outlined"
            style={{ fontVariationSettings: isActive(item.path) && item.filled ? "'FILL' 1" : '' }}
          >
            {item.icon}
          </span>
          <span className="text-[10px] font-medium uppercase tracking-widest mt-1">
            {item.label}
          </span>
        </Link>
      ))}
    </nav>
  )
}

// FAB for creating new proposal (mobile)
export function CreateProposalFAB() {
  return (
    <Link
      href="/create-proposal"
      className="fixed bottom-24 right-6 w-14 h-14 rounded-full bg-primary text-on-primary shadow-[0_0_30px_rgba(125,211,252,0.4)] flex items-center justify-center hover:scale-110 active:scale-90 transition-all z-40 lg:hidden"
    >
      <span className="material-symbols-outlined scale-125">add</span>
    </Link>
  )
}
