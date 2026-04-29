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
    <nav className="sticky top-0 z-50 flex justify-between items-center w-full px-6 py-4 bg-surface-dim/60 backdrop-blur-xl border-b border-outline/20 shadow-[0_0_30px_rgba(255,73,164,0.05)] font-sans antialiased tracking-tight">
      <div className="flex items-center gap-8">
        <Link href="/proposals" className="flex items-center gap-3 group transition-all">
          <div className="relative w-64 h-10 overflow-hidden rounded-xl border border-outline/20 group-hover:border-primary/40 group-hover:shadow-primary/20 transition-all bg-surface/40">
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
            className={`${isActive('/proposals') ? 'text-primary border-b-2 border-primary pb-1' : 'text-on-surface-variant hover:text-primary transition-colors'}`}
          >
            Proposals
          </Link>
          <Link
            href="/treasury"
            className={`${isActive('/treasury') ? 'text-primary border-b-2 border-primary pb-1' : 'text-on-surface-variant hover:text-primary transition-colors'}`}
          >
            Treasury
          </Link>
          <Link
            href="/delegates"
            className={`${isActive('/delegates') ? 'text-primary border-b-2 border-primary pb-1' : 'text-on-surface-variant hover:text-primary transition-colors'}`}
          >
            Delegates
          </Link>
          <Link
            href="/cross-chain"
            className={`${isActive('/cross-chain') ? 'text-primary border-b-2 border-primary pb-1' : 'text-on-surface-variant hover:text-primary transition-colors'}`}
          >
            Cross-Chain
          </Link>
        </div>
      </div>
      <div className="flex items-center gap-4">
        <ConnectButton />
      </div>
    </nav>
  )
}
