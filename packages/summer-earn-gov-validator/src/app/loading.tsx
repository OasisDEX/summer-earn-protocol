import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsListSkeleton } from '@/components/ProposalsListSkeleton'

export default function Loading() {
  return (
    <DashboardLayout>
      <ProposalsListSkeleton />
    </DashboardLayout>
  )
}
