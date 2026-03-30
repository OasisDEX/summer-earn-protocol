import { DashboardLayout } from '@/components/DashboardLayout'
import { TreasuryView } from '@/components/TreasuryView'
import { fetchTreasuryBalances } from '@/services/treasury'

// Revalidate every 5 minutes
export const revalidate = 300

export default async function TreasuryPage() {
  const treasury = await fetchTreasuryBalances()

  return (
    <DashboardLayout activeTab="treasury">
      <TreasuryView initialData={treasury} />
    </DashboardLayout>
  )
}
