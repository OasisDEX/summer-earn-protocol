import { connection } from 'next/server'

import { DashboardLayout } from '@/components/DashboardLayout'
import { TreasuryView } from '@/components/TreasuryView'
import { getTreasuryBalancesCached } from '@/services/treasury-cached'

export default async function TreasuryPage() {
  await connection()
  const treasury = await getTreasuryBalancesCached()
  return (
    <DashboardLayout activeTab="treasury">
      <TreasuryView initialData={treasury} />
    </DashboardLayout>
  )
}
