import { Suspense } from 'react'
import { notFound } from 'next/navigation'

import { AdminTabs } from '@/components/admin/AdminTabs'
import { buildAdminTabs } from '@/components/admin/adminTabs.config'
import { RebalancePanel } from '@/components/admin/RebalancePanel'
import { ConnectButton } from '@/components/ConnectButton'
import { Topbar } from '@/components/shell/Topbar'
import { getInstitutionBySlug } from '@/config/institutions'
import { getAppEnvironment } from '@/lib/server/appEnvironment'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function AdminRebalancePage({ params }: PageProps) {
  const { institutionId, fleetAddress } = await params
  const env = await getAppEnvironment()
  const inst = getInstitutionBySlug(env, institutionId)
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
          { label: 'Admin · Rebalance' },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page max-w-[760px]">
        <AdminTabs tabs={buildAdminTabs(inst.slug, fleet.fleetCommander)} />
        <Suspense fallback={<div className="h-64 animate-pulse rounded-lg bg-[var(--surface)]" />}>
          <RebalancePanel institution={inst} fleet={fleet} />
        </Suspense>
      </div>
    </>
  )
}
