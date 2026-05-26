import { Suspense } from 'react'
import { notFound } from 'next/navigation'

import { ConnectButton } from '@/components/ConnectButton'
import { FleetDetailBody } from '@/components/fleet/FleetDetailBody'
import { Topbar } from '@/components/shell/Topbar'
import { getInstitutionBySlug } from '@/config/institutions'
import { loadFleet } from '@/lib/server/loadFleet'
import { loadRoundsVault } from '@/lib/server/loadRoundsVault'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function FleetPage({ params }: PageProps) {
  const { institutionId, fleetAddress } = await params
  const inst = getInstitutionBySlug(institutionId)
  if (!inst) notFound()
  const fleet = inst.fleets.find(
    (f) => f.fleetCommander.toLowerCase() === fleetAddress.toLowerCase(),
  )
  if (!fleet) notFound()

  const [loaded, inputRv, outputRv] = await Promise.all([
    loadFleet(inst.chainId, fleet.fleetCommander),
    fleet.roundsVaultInput
      ? loadRoundsVault(inst.chainId, fleet.roundsVaultInput)
      : Promise.resolve(null),
    fleet.roundsVaultOutput
      ? loadRoundsVault(inst.chainId, fleet.roundsVaultOutput)
      : Promise.resolve(null),
  ])

  return (
    <>
      <Topbar
        crumbs={[
          { href: '/institutions', label: 'Institutions' },
          { href: `/institutions/${inst.slug}`, label: inst.displayName },
          { label: fleet.label },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page">
        <Suspense fallback={<div className="mt-8 h-40 animate-pulse rounded-lg bg-[var(--surface)]" />}>
          <FleetDetailBody
            institution={inst}
            fleet={fleet}
            loadedFleet={loaded}
            initialInputRoundsVault={inputRv}
            initialOutputRoundsVault={outputRv}
          />
        </Suspense>
      </div>
    </>
  )
}
