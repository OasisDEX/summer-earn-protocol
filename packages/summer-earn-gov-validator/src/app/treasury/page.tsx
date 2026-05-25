import { Suspense } from 'react'
import { connection } from 'next/server'

import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsListSkeleton } from '@/components/ProposalsListSkeleton'
import { TreasuryView } from '@/components/TreasuryView'
import { getTreasuryBalancesCached } from '@/services/treasury-cached'

export default function TreasuryPage() {
  return (
    <DashboardLayout activeTab="treasury">
      <Suspense fallback={<ProposalsListSkeleton />}>
        <TreasuryServer />
      </Suspense>
    </DashboardLayout>
  )
}

async function TreasuryServer() {
  await connection()
  const treasury = await getTreasuryBalancesCached()
  return <TreasuryView initialData={treasury} />
}
