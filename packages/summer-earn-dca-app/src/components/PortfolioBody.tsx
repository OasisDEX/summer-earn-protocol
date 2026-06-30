'use client'

import { useEffect } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { type Address, getAddress } from 'viem'
import { useAccount } from 'wagmi'

import { PortfolioKpis } from '@/components/dashboard/PortfolioKpis'
import { StrategyList } from '@/components/StrategyList'
import { Button } from '@/components/ui/Button'
import { useStrategiesByOwner } from '@/hooks/useDcaSubgraph'
import { shortAddress } from '@/lib/format'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import { type ChainId, chainSlug } from '@/types/chain'

interface Props {
  chainId: ChainId
  urlAddress?: Address
  initialStrategies?: SubgraphStrategy[]
}

export function PortfolioBody({ chainId, urlAddress, initialStrategies }: Props) {
  const { address: walletAddress } = useAccount()
  const router = useRouter()
  const walletAddr = walletAddress ? (getAddress(walletAddress) as Address) : undefined

  // On wallet-connect from the URL-less landing, hop to the canonical
  // /portfolio/{address} route so the next paint is server-rendered.
  useEffect(() => {
    if (walletAddr && !urlAddress) {
      router.replace(`/portfolio/${walletAddr.toLowerCase()}?chain=${chainSlug(chainId)}`)
    }
  }, [walletAddr, urlAddress, router, chainId])

  const effectiveOwner = urlAddress ?? walletAddr

  // Only honour the server-resolved list when it matches the address we're
  // about to query for.
  const seedStrategies =
    initialStrategies && urlAddress && effectiveOwner === urlAddress ? initialStrategies : undefined

  const { data: strategies } = useStrategiesByOwner(chainId, effectiveOwner, seedStrategies)
  const active = (strategies ?? []).filter((s) => s.status === 'ACTIVE').length
  const total = strategies?.length ?? 0

  const isReadonly = Boolean(
    walletAddr && urlAddress && walletAddr.toLowerCase() !== urlAddress.toLowerCase(),
  )

  return (
    <div className="page">
      <header className="mb-7 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="h1">Portfolio</h1>
          <p className="mt-1 font-mono text-xs text-[var(--text-3)]">
            {urlAddress ? (
              <>
                {shortAddress(urlAddress)} · {active} active · {total} total
              </>
            ) : (
              <>
                {active} active · {total} total
              </>
            )}
          </p>
        </div>
      </header>

      {isReadonly && walletAddr && (
        <div className="mb-6 flex items-center justify-between gap-3 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 py-3 text-sm">
          <span className="text-[var(--text-2)]">
            Viewing {shortAddress(urlAddress!)} — read-only. Connect as that wallet to edit or pause
            strategies.
          </span>
          <Link href={`/portfolio/${walletAddr.toLowerCase()}?chain=${chainSlug(chainId)}`}>
            <Button variant="ghost" size="sm">
              View my portfolio
            </Button>
          </Link>
        </div>
      )}

      {effectiveOwner && strategies && <PortfolioKpis chainId={chainId} strategies={strategies} />}

      <div className="mt-8">
        <StrategyList chainId={chainId} owner={effectiveOwner} readonly={isReadonly} />
      </div>
    </div>
  )
}
