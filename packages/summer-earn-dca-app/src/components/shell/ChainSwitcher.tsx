'use client'

import { usePathname, useRouter } from 'next/navigation'
import { useSwitchChain } from 'wagmi'

import { Segmented } from '@/components/ui/Segmented'
import { CHAIN_NAMES } from '@/config/chains'
import { useActiveChain } from '@/hooks/useActiveChain'
import { type ChainId, chainSlug, SUPPORTED_CHAIN_IDS } from '@/types/chain'

// Compact segmented control over the supported chains. Selecting a chain:
//   - re-routes so the URL encodes the new chain (slug stays the source of
//     truth that `useActiveChain` reads back), and
//   - asks the connected wallet to switch chains (no-op when disconnected).
export function ChainSwitcher() {
  const pathname = usePathname() ?? '/'
  const router = useRouter()
  const active = useActiveChain()
  const { switchChain } = useSwitchChain()

  const onSelect = (next: ChainId) => {
    if (next === active) return
    const slug = chainSlug(next)

    // /strategy/<slug>/<id> carries the chain in the path; a strategy id is
    // chain-specific, so hop back to the portfolio for the new chain instead
    // of rewriting the segment to a foreign id.
    if (pathname.startsWith('/strategy/')) {
      router.push(`/portfolio?chain=${slug}`)
    } else {
      router.push(`${pathname}?chain=${slug}`)
    }

    // Guard: switchChain is a no-op connector call when no wallet is connected.
    try {
      switchChain({ chainId: Number(next) })
    } catch {
      // Disconnected / unsupported — the URL still reflects the selection.
    }
  }

  return (
    <Segmented
      value={active}
      onChange={onSelect}
      options={SUPPORTED_CHAIN_IDS.map((id) => ({ value: id, label: CHAIN_NAMES[id] }))}
    />
  )
}
