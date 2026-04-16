import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsList } from '@/components/ProposalsList'
import { fetchAllProposals } from '@/services/subgraph'
import { TransformedProposal } from '@/types/governance'
import { transformProposal } from '@/utils/proposal-transformer'

// Revalidate every 60 seconds (ISR)
export const revalidate = 60

async function getV1Proposals(): Promise<TransformedProposal[]> {
  try {
    // Fetch proposals where governor is NOT the V2 governor
    const v1Proposals = await fetchAllProposals({ isV1: true })
    return v1Proposals.map((p) => transformProposal(p))
  } catch (error) {
    console.error('Error fetching V1 proposals:', error)
    return []
  }
}

export default async function V1ProposalsPage() {
  const proposals = await getV1Proposals()

  return (
    <DashboardLayout activeTab="proposals">
      <div className="mb-6">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-400/10 border border-amber-400/20 text-amber-500 text-xs font-bold uppercase tracking-widest mb-4">
          <span className="material-symbols-outlined text-sm">archive</span>
          V1 Archive
        </div>
      </div>
      <ProposalsList initialProposals={proposals} detailPrefix="/proposal/v1" />
    </DashboardLayout>
  )
}
