import { Suspense } from 'react'
import { notFound } from 'next/navigation'

import { AdminTabs } from '@/components/admin/AdminTabs'
import { buildAdminTabs } from '@/components/admin/adminTabs.config'
import { TransferControlPanel } from '@/components/admin/TransferControlPanel'
import { ConnectButton } from '@/components/ConnectButton'
import { Topbar } from '@/components/shell/Topbar'
import { getInstitutionBySlug } from '@/config/institutions'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function AdminTransfersPage({ params }: PageProps) {
  const { institutionId, fleetAddress } = await params
  const inst = getInstitutionBySlug(institutionId)
  if (!inst) notFound()
  const fleet = inst.fleets.find(
    (f) => f.fleetCommander.toLowerCase() === fleetAddress.toLowerCase(),
  )
  if (!fleet) notFound()

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
          { label: 'Admin · Transfers' },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page max-w-[820px]">
        <AdminTabs tabs={buildAdminTabs(inst.slug, fleet.fleetCommander)} />
        <Suspense fallback={<div className="h-64 animate-pulse rounded-lg bg-[var(--surface)]" />}>
          <TransferControlPanel institution={inst} fleet={fleet} />
        </Suspense>
      </div>
    </>
  )
}
