'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { formatUnits } from 'viem'
import { useAccount, useBalance, useDisconnect } from 'wagmi'

import { useActiveChain } from '@/hooks/useActiveChain'
import { shortAddress } from '@/lib/format'
import { chainSlug } from '@/types/chain'

interface NavItem {
  href: string
  label: string
  match: (pathname: string) => boolean
}

const NAV: NavItem[] = [
  {
    href: '/portfolio',
    label: 'Portfolio',
    match: (p) => p === '/' || p.startsWith('/portfolio') || p.startsWith('/strategy'),
  },
  {
    href: '/create',
    label: 'New strategy',
    match: (p) => p.startsWith('/create'),
  },
]

export function Sidebar() {
  const pathname = usePathname() ?? '/'
  const { address, isConnected } = useAccount()
  const { disconnect } = useDisconnect()
  const activeChainId = useActiveChain()
  const slug = chainSlug(activeChainId)
  const balance = useBalance({ address, chainId: Number(activeChainId) })

  return (
    <aside className="sticky top-0 flex h-screen flex-col gap-6 border-r border-[var(--border-faint)] bg-[rgba(8,8,12,0.6)] px-4 py-6 backdrop-blur-[20px]">
      <div className="flex items-center gap-2.5 px-2 py-1 text-[18px] font-semibold tracking-[-0.02em]">
        <span
          className="relative h-[22px] w-[22px] rounded-[8px]"
          style={{
            background: 'linear-gradient(135deg, var(--pink) 0%, var(--violet) 100%)',
            boxShadow: '0 0 0 4px rgba(255,73,160,0.10)',
          }}
        >
          <span
            className="absolute inset-[5px] rounded-[4px]"
            style={{ background: 'var(--bg)' }}
          />
        </span>
        summer.fi
      </div>

      <nav className="flex flex-col gap-0.5">
        <div className="px-3 pb-1 pt-2 text-[11px] uppercase tracking-[0.08em] text-[var(--text-4)]">
          Workspace
        </div>
        {NAV.map((item) => {
          const active = item.match(pathname)
          const base =
            item.href === '/portfolio' && address
              ? `/portfolio/${address.toLowerCase()}`
              : item.href
          // Carry the active chain so the destination keeps the current chain.
          const href = `${base}?chain=${slug}`
          return (
            <Link
              key={item.href}
              href={href}
              className={[
                'flex w-full items-center gap-2.5 rounded-md border border-transparent px-3 py-[9px] text-sm transition',
                active
                  ? 'bg-[var(--surface)] text-[var(--text)] border-[var(--border)]'
                  : 'bg-transparent text-[var(--text-2)] hover:bg-[var(--surface)] hover:text-[var(--text)]',
              ].join(' ')}
            >
              {item.label}
            </Link>
          )
        })}
      </nav>

      <div className="mt-auto rounded-lg border border-[var(--border-faint)] bg-[var(--surface)] p-3.5 text-sm">
        {isConnected && address ? (
          <>
            <div className="flex items-center gap-2 font-mono text-xs text-[var(--text-2)]">
              <span className="inline-block h-1.5 w-1.5 rounded-full bg-[var(--lime)]" />
              {shortAddress(address)}
            </div>
            <div className="mt-2 font-mono text-[11px] text-[var(--text-3)]">
              {balance.data
                ? `${Number(formatUnits(balance.data.value, balance.data.decimals)).toFixed(4)} ${balance.data.symbol}`
                : '—'}
            </div>
            <button
              type="button"
              onClick={() => disconnect()}
              className="mt-2.5 w-full rounded-sm border border-[var(--border)] bg-transparent px-2.5 py-1.5 text-xs text-[var(--text-2)] transition hover:border-[var(--border-strong)] hover:text-[var(--text)]"
            >
              Disconnect
            </button>
          </>
        ) : (
          <button
            type="button"
            onClick={() => window.appKit?.open()}
            className="w-full rounded-pill bg-[var(--pink)] px-3 py-2 text-xs font-semibold text-[#1A0A12] hover:bg-[var(--pink-2)]"
          >
            Connect wallet
          </button>
        )}
      </div>
    </aside>
  )
}
