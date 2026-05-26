import { Suspense } from 'react'
import { notFound } from 'next/navigation'

import { AdminTabs, buildAdminTabs } from '@/components/admin/AdminTabs'
import { RoundsControlPanel } from '@/components/admin/RoundsControlPanel'
import { ConnectButton } from '@/components/ConnectButton'
import { Topbar } from '@/components/shell/Topbar'
import { getInstitutionBySlug } from '@/config/institutions'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function AdminRoundsPage({ params }: PageProps) {
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
          { label: 'Admin · Rounds' },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page max-w-[820px]">
        <AdminTabs tabs={buildAdminTabs(inst.slug, fleet.fleetCommander)} />
        <Suspense fallback={<div className="h-64 animate-pulse rounded-lg bg-[var(--surface)]" />}>
          <RoundsControlPanel institution={inst} fleet={fleet} />
        </Suspense>
      </div>
    </>
  )
}
