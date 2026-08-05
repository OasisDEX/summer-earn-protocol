import { DashboardLayout } from '@/components/DashboardLayout'
import { TreasuryView } from '@/components/TreasuryView'
import { getTreasuryBalancesCached } from '@/services/treasury-cached'

export default async function TreasuryPage() {
  const treasury = await getTreasuryBalancesCached()
  return (
    <DashboardLayout activeTab="treasury">
      <TreasuryView initialData={treasury} />
    </DashboardLayout>
  )
}
