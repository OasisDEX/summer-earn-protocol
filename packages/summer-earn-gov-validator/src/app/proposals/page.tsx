import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsList } from '@/components/ProposalsList'
import { fetchAllProposals } from '@/services/subgraph'
import { TransformedProposal } from '@/types/governance'
import { transformProposal } from '@/utils/proposal-transformer'

// Revalidate every 60 seconds (ISR)
export const revalidate = 60

async function getProposals(): Promise<TransformedProposal[]> {
  try {
    const proposalsWithCrossChain = await fetchAllProposals()
    return proposalsWithCrossChain.map((p) => transformProposal(p))
  } catch (error) {
    console.error('Error fetching proposals:', error)
    // Return empty array on error - could also throw or return fallback
    return []
  }
}

export default async function ProposalsPage() {
  const proposals = await getProposals()

  return (
    <DashboardLayout activeTab="proposals">
      <ProposalsList initialProposals={proposals} />
    </DashboardLayout>
  )
}
