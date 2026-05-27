import { Suspense } from 'react'
import { connection } from 'next/server'

import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsList } from '@/components/ProposalsList'
import { ProposalsListSkeleton } from '@/components/ProposalsListSkeleton'
import { getProposalsCached } from '@/services/subgraph-cached'
import { TransformedProposal } from '@/types/governance'
import { transformProposal } from '@/utils/proposal-transformer'

export default function ProposalsPage() {
  return (
    <DashboardLayout activeTab="proposals">
      <Suspense fallback={<ProposalsListSkeleton />}>
        <ProposalsListServer />
      </Suspense>
    </DashboardLayout>
  )
}

async function ProposalsListServer() {
  await connection()

  let proposals: TransformedProposal[]
  try {
    const raw = await getProposalsCached()
    proposals = raw.map(transformProposal)
  } catch (error) {
    console.error('Error fetching proposals:', error)
    proposals = []
  }

  return <ProposalsList initialProposals={proposals} />
}
