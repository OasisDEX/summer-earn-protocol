import { connection } from 'next/server'

import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsList } from '@/components/ProposalsList'
import { getProposalsCached } from '@/services/subgraph-cached'
import { TransformedProposal } from '@/types/governance'
import { transformProposal } from '@/utils/proposal-transformer'

export default async function ProposalsPage() {
  await connection()
  let proposals: TransformedProposal[] = []
  try {
    const raw = await getProposalsCached()
    proposals = raw.map((p) => transformProposal(p))
  } catch (error) {
    console.error('Error fetching proposals:', error)
  }

  return (
    <DashboardLayout activeTab="proposals">
      <ProposalsList initialProposals={proposals} />
    </DashboardLayout>
  )
}
