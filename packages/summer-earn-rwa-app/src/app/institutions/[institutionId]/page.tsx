import { Suspense } from 'react'
import { notFound } from 'next/navigation'

import { ConnectButton } from '@/components/ConnectButton'
import { InstitutionOverviewBody } from '@/components/institutions/InstitutionOverviewBody'
import { Topbar } from '@/components/shell/Topbar'
import { getInstitutionBySlug } from '@/config/institutions'
import { getAppEnvironment } from '@/lib/server/appEnvironment'
import { loadInstitution } from '@/lib/server/loadInstitution'

interface PageProps {
  params: Promise<{ institutionId: string }>
}

export default async function InstitutionPage({ params }: PageProps) {
  const { institutionId } = await params
  const env = await getAppEnvironment()
  const inst = getInstitutionBySlug(env, institutionId)
  if (!inst) notFound()
  const loaded = await loadInstitution(env, institutionId)
  if (!loaded) notFound()

  return (
    <>
      <Topbar
        crumbs={[{ href: '/institutions', label: 'Institutions' }, { label: loaded.displayName }]}
        actions={<ConnectButton />}
      />
      <div className="page">
        <h1 className="h1">{loaded.displayName}</h1>
        <p className="mt-2 text-[var(--text-3)]">
          chainId {loaded.chainId} · ProtocolAccessManagerV2{' '}
          <span className="font-mono text-xs">{loaded.protocolAccessManager}</span>
        </p>
        <Suspense
          fallback={<div className="mt-8 h-40 animate-pulse rounded-lg bg-[var(--surface)]" />}
        >
          <InstitutionOverviewBody institution={loaded} />
        </Suspense>
      </div>
    </>
  )
}
