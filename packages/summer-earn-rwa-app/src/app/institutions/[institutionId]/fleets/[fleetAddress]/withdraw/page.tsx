import { Suspense } from 'react'
import { notFound } from 'next/navigation'
import { createPublicClient } from 'viem'

import { roundsVaultOutputAbi } from '@/abis/RoundsVaultOutput'
import { ConnectButton } from '@/components/ConnectButton'
import { DepositForm } from '@/components/rounds/DepositForm'
import { Topbar } from '@/components/shell/Topbar'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { getInstitutionBySlug } from '@/config/institutions'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function WithdrawPage({ params }: PageProps) {
  const { institutionId, fleetAddress } = await params
  const inst = getInstitutionBySlug(institutionId)
  if (!inst) notFound()
  const fleet = inst.fleets.find(
    (f) => f.fleetCommander.toLowerCase() === fleetAddress.toLowerCase(),
  )
  if (!fleet || !fleet.roundsVaultOutput) notFound()

  const client = createPublicClient({
    transport: createRpcTransport(CHAIN_RPC_URLS[inst.chainId]),
    chain: VIEM_CHAIN_ENTITIES[inst.chainId],
  })
  const depositToken = (await client.readContract({
    address: fleet.roundsVaultOutput,
    abi: roundsVaultOutputAbi,
    functionName: 'asset',
  })) as `0x${string}`

  return (
    <>
      <Topbar
        crumbs={[
          { href: '/institutions', label: 'Institutions' },
          { href: `/institutions/${inst.slug}`, label: inst.displayName },
          {
            href: `/institutions/${inst.slug}/fleets/${fleet.fleetCommander}`,
            label: fleet.label,
          },
          { label: 'Withdraw' },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page max-w-[640px]">
        <Suspense fallback={<div className="h-64 animate-pulse rounded-lg bg-[var(--surface)]" />}>
          <DepositForm
            institution={inst}
            fleet={fleet}
            roundsVaultAddress={fleet.roundsVaultOutput}
            depositToken={depositToken}
            title="Queue withdrawal"
            description="Your fleet shares are queued for the next settlement. You'll receive the underlying asset (e.g. USDC) once the keeper settles the round."
          />
        </Suspense>
      </div>
    </>
  )
}
