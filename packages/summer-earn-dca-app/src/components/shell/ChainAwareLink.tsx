'use client'

import type { ReactNode } from 'react'
import Link from 'next/link'

import { useActiveChain } from '@/hooks/useActiveChain'
import { chainSlug } from '@/types/chain'

// A Link that preserves the active chain on relative navigations. Appends
// `?chain=<active-slug>` to a relative href unless it already pins a chain
// (query) or targets a `/strategy/<slug>/...` route (where the chain is a path
// segment). Lets breadcrumbs / CTAs keep the multichain URL convention without
// threading `searchParams` through the cacheComponents-gated server pages —
// the chain is read on the client via useActiveChain (same as ChainSwitcher).
export function ChainAwareLink({
  href,
  className,
  children,
}: {
  href: string
  className?: string
  children: ReactNode
}) {
  const chain = useActiveChain()
  let target = href
  if (href.startsWith('/') && !href.startsWith('/strategy/') && !/[?&]chain=/.test(href)) {
    target = `${href}${href.includes('?') ? '&' : '?'}chain=${chainSlug(chain)}`
  }
  return (
    <Link href={target} className={className}>
      {children}
    </Link>
  )
}
