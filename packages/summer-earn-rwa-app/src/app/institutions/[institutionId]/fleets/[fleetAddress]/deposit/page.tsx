import { Suspense } from 'react'
import { notFound } from 'next/navigation'
import { createPublicClient } from 'viem'

import { roundsVaultInputAbi } from '@/abis/RoundsVaultInput'
import { ConnectButton } from '@/components/ConnectButton'
import { DepositForm } from '@/components/rounds/DepositForm'
import { Topbar } from '@/components/shell/Topbar'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { getInstitutionBySlug } from '@/config/institutions'
import { getAppEnvironment } from '@/lib/server/appEnvironment'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function DepositPage({ params }: PageProps) {
  const { institutionId, fleetAddress } = await params
  const env = await getAppEnvironment()
  const inst = getInstitutionBySlug(env, institutionId)
  if (!inst) notFound()
  const fleet = inst.fleets.find(
    (f) => f.fleetCommander.toLowerCase() === fleetAddress.toLowerCase(),
  )
  if (!fleet || !fleet.roundsVaultInput) notFound()

  // Resolve the underlying deposit token (asset() on the input rounds-vault)
  // server-side so the form has it on first render.
  const client = createPublicClient({
    transport: createRpcTransport(CHAIN_RPC_URLS[inst.chainId]),
    chain: VIEM_CHAIN_ENTITIES[inst.chainId],
  })
  const depositToken = (await client.readContract({
    address: fleet.roundsVaultInput,
    abi: roundsVaultInputAbi,
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
          { label: 'Deposit' },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page max-w-[640px]">
        <Suspense fallback={<div className="h-64 animate-pulse rounded-lg bg-[var(--surface)]" />}>
          <DepositForm
            institution={inst}
            fleet={fleet}
            roundsVaultAddress={fleet.roundsVaultInput}
            depositToken={depositToken}
            title="Queue deposit"
            description="Your deposit joins the current round. It mints a non-transferable receipt that becomes redeemable for fleet shares once the keeper settles the round."
          />
        </Suspense>
      </div>
    </>
  )
}
