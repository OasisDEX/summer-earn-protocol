'use client'

import Image from 'next/image'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

import { ConnectButton } from './ConnectButton'

export function TopNavBar() {
  const pathname = usePathname()

  const isActive = (path: string) => {
    if (path === '/proposals') return pathname === '/proposals' || pathname === '/'
    return pathname.startsWith(path)
  }

  return (
    <nav className="sticky top-0 z-50 flex justify-between items-center w-full px-6 py-4 bg-slate-950/60 backdrop-blur-xl border-b border-sky-400/10 shadow-[0_0_30px_rgba(125,211,252,0.05)] font-sans antialiased tracking-tight">
      <div className="flex items-center gap-8">
        <Link href="/proposals" className="flex items-center gap-3 group transition-all">
          <div className="relative w-64 h-10 overflow-hidden rounded-xl border-sky-400/20  group-hover:border-sky-400/40 group-hover:shadow-sky-500/20 transition-all bg-slate-900/40">
            <Image
              src="/images/lazy_summer_dao_logo.png"
              alt="Lazy Summer DAO"
              fill
              className="object-contain p-1.5"
            />
          </div>
          {/* <span className="text-2xl font-semibold tracking-tighter text-sky-300 group-hover:text-primary transition-colors hidden sm:block">
            Glacier
          </span> */}
        </Link>
        <div className="hidden md:flex gap-6">
          <Link
            href="/proposals"
            className={`${isActive('/proposals') ? 'text-sky-300 border-b-2 border-sky-300 pb-1' : 'text-slate-400 hover:text-sky-200 transition-colors'}`}
          >
            Proposals
          </Link>
          <Link
            href="/treasury"
            className={`${isActive('/treasury') ? 'text-sky-300 border-b-2 border-sky-300 pb-1' : 'text-slate-400 hover:text-sky-200 transition-colors'}`}
          >
            Treasury
          </Link>
          <Link
            href="/delegates"
            className={`${isActive('/delegates') ? 'text-sky-300 border-b-2 border-sky-300 pb-1' : 'text-slate-400 hover:text-sky-200 transition-colors'}`}
          >
            Delegates
          </Link>
          <Link
            href="/cross-chain"
            className={`${isActive('/cross-chain') ? 'text-sky-300 border-b-2 border-sky-300 pb-1' : 'text-slate-400 hover:text-sky-200 transition-colors'}`}
          >
            Cross-Chain
          </Link>
        </div>
      </div>
      <div className="flex items-center gap-4">
        <div className="relative hidden lg:block">
          <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-sm">
            search
          </span>
          <input
            className="bg-slate-900/50 border border-sky-400/10 rounded-full pl-10 pr-4 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-sky-300/50 w-64 transition-all focus:bg-slate-900/80"
            placeholder="Search..."
            type="text"
          />
        </div>
        <ConnectButton />
      </div>
    </nav>
  )
}
