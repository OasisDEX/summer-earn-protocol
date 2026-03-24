import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsList } from '@/components/ProposalsList'
import { getChainNameById, HUB_CHAIN_ID } from '@/config/chains'
import { fetchAllProposals, ProposalWithCrossChain } from '@/services/subgraph'
import { extractProposalMetadata } from '@/utils/text'

// Revalidate every 60 seconds (ISR)
export const revalidate = 60

// Transform subgraph data to match our Proposal interface
interface TransformedProposal {
  id: string
  displayId: string | null
  status:
    | 'Active'
    | 'Executed'
    | 'Queued'
    | 'Defeated'
    | 'Executed on Hub'
    | 'Succeeded'
    | 'Canceled'
  chain: string
  title: string
  description: string
  quorumProgress: number
  timeRemaining: string
  forVotes: number
  againstVotes: number
  abstainVotes: number
  forPercent: number
  againstPercent: number
  abstainPercent: number
  quorumReached: boolean
  targets: string[]
  values: string[]
  calldatas: string[]
}

function transformProposal(proposalWithCrossChain: ProposalWithCrossChain): TransformedProposal {
  const proposal = proposalWithCrossChain.baseProposal
  // Map subgraph status to our status format
  const statusMap: Record<string, TransformedProposal['status']> = {
    Active: 'Active',
    Executed: 'Executed',
    Queued: 'Queued',
    Defeated: 'Defeated',
    Canceled: 'Canceled',
    Succeeded: 'Succeeded',
    Pending: 'Active',
  }

  let finalStatus = statusMap[proposal.status] || 'Active'
  if (finalStatus === 'Executed' && proposalWithCrossChain.crossChainProposals.length > 0) {
    const hasPendingCrossChain = proposalWithCrossChain.crossChainProposals.some(
      (ccp: any) => ccp.status !== 'Executed',
    )
    if (hasPendingCrossChain) {
      finalStatus = 'Executed on Hub'
    }
  }

  // Get chain from proposal , if multiple chains get chain name by chain Id and join a string to show mutliple
  // const chainsString = proposal.chains.map((chainId) => getChainNameById(chainId)).join(', ')
  const chains = [...proposal.chains, HUB_CHAIN_ID]
  const chain = chains.map((chainId) => getChainNameById(chainId)).join(', ')

  // Extract title and displayId from description
  const { title, displayId } = extractProposalMetadata(proposal.description || '')

  // Calculate time remaining (mock for now - would need block timestamp from chain)
  const timeRemaining = proposal.status === 'Active' ? 'Active' : proposal.status

  // Mock voting data (would need to query vote counts from subgraph)
  const forVotes = 65 // MOCK: Replace with actual vote count
  const againstVotes = 25
  const abstainVotes = 10
  const totalVotes = forVotes + againstVotes + abstainVotes
  const quorumProgress = totalVotes > 0 ? Math.round((forVotes / totalVotes) * 100) : 0

  return {
    id: proposal.id,
    displayId,
    status: finalStatus,
    chain,
    title,
    description: proposal.description || '',
    quorumProgress,
    timeRemaining,
    forVotes,
    againstVotes,
    abstainVotes,
    forPercent: 0,
    againstPercent: 0,
    abstainPercent: 0,
    quorumReached: false,
    targets: proposal.targets || [],
    values: proposal.values || [],
    calldatas: proposal.calldatas || [],
  }
}

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
