import { Suspense } from 'react'
import { notFound } from 'next/navigation'

import { ConnectButton } from '@/components/ConnectButton'
import { ReceiptTable } from '@/components/rounds/ReceiptTable'
import { Topbar } from '@/components/shell/Topbar'
import { getInstitutionBySlug } from '@/config/institutions'

interface PageProps {
  params: Promise<{ institutionId: string; fleetAddress: string }>
}

export default async function ReceiptsPage({ params }: PageProps) {
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
          { label: 'Receipts' },
        ]}
        actions={<ConnectButton />}
      />
      <div className="page">
        <h1 className="h1">Your receipts</h1>
        <p className="mt-2 text-sm text-[var(--text-3)]">
          Cancel during an open round to get your deposit back 1:1. Once the keeper closes the round
          you must wait for settlement, then claim the exchange asset at the settled rate.
        </p>
        <Suspense
          fallback={<div className="mt-8 h-64 animate-pulse rounded-lg bg-[var(--surface)]" />}
        >
          <ReceiptTable institution={inst} fleet={fleet} initialReceipts={[]} />
        </Suspense>
      </div>
    </>
  )
}
