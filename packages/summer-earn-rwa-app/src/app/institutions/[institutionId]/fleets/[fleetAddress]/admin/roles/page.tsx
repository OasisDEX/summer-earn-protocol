import { Suspense } from 'react'
import { notFound } from 'next/navigation'

import { AdminTabs } from '@/components/admin/AdminTabs'
import { buildAdminTabs } from '@/components/admin/adminTabs.config'
import { RoleManagerPanel } from '@/components/admin/RoleManagerPanel'
import { ConnectButton } from '@/components/ConnectButton'
import { Topbar } from '@/components/shell/Topbar'
import { getInstitutionBySlug } from '@/config/institutions'
import { gqlFetch } from '@/lib/subgraph/client'
import { INSTITUTION_BY_CONFIGURATION_MANAGER } from '@/lib/subgraph/queries/institutions'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

interface InstResp {
  institutions: Array<{ id: string }>
}

export default async function AdminRolesPage({ params }: PageProps) {
  const { institutionId, fleetAddress } = await params
  const inst = getInstitutionBySlug(institutionId)
  if (!inst) notFound()
  const fleet = inst.fleets.find(
    (f) => f.fleetCommander.toLowerCase() === fleetAddress.toLowerCase(),
  )
  if (!fleet) notFound()

  // Resolve the bytes32 institutionId from the subgraph by configurationManager
  // so the live roles list can populate. Failures are non-fatal — the panel
  // still works for grant/revoke without it.
  let institutionSubgraphId: string | undefined
  try {
    const data = await gqlFetch<InstResp>(inst.chainId, INSTITUTION_BY_CONFIGURATION_MANAGER, {
      cm: inst.configurationManager.toLowerCase(),
    })
    institutionSubgraphId = data.institutions[0]?.id
  } catch {
    // ignore — falls back to undefined
  }

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
          { label: 'Admin · Roles' },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page max-w-[760px]">
        <AdminTabs tabs={buildAdminTabs(inst.slug, fleet.fleetCommander)} />
        <Suspense fallback={<div className="h-64 animate-pulse rounded-lg bg-[var(--surface)]" />}>
          <RoleManagerPanel
            institution={inst}
            fleet={fleet}
            institutionSubgraphId={institutionSubgraphId}
          />
        </Suspense>
      </div>
    </>
  )
}
