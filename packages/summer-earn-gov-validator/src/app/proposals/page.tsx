import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalsList } from '@/components/ProposalsList'
import { getChainNameById, HUB_CHAIN_ID } from '@/config/chains'
import { fetchAllProposals } from '@/services/subgraph'
import { FinalStatus, ProposalWithCrossChain, TransformedProposal } from '@/types/governance'
import { extractProposalMetadata } from '@/utils/text'

// Revalidate every 60 seconds (ISR)
export const revalidate = 60

function transformProposal(proposalWithCrossChain: ProposalWithCrossChain): TransformedProposal {
  const proposal = proposalWithCrossChain.baseProposal
  // Map subgraph status to our status format

  let finalStatus: FinalStatus = proposal.status
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
  const { title, displayId, cleanDescription } = extractProposalMetadata(proposal.description || '')

  const currentTimestampSeconds = Math.floor(Date.now() / 1000)
  const voteStartSeconds = Number(proposal.voteStart)
  const voteEndSeconds = Number(proposal.voteEnd)

  const timeRemaining =
    currentTimestampSeconds >= voteStartSeconds
      ? voteEndSeconds - currentTimestampSeconds
      : voteStartSeconds - currentTimestampSeconds

  if (currentTimestampSeconds >= voteStartSeconds && currentTimestampSeconds <= voteEndSeconds) {
    finalStatus = 'Active'
  }
  // Mock voting data (would need to query vote counts from subgraph)
  const forVotes = Number(proposal.forVotes) / 1e18
  const againstVotes = Number(proposal.againstVotes) / 1e18
  const abstainVotes = Number(proposal.abstainVotes) / 1e18
  const totalVotes = forVotes + againstVotes + abstainVotes
  const quorum = Number(proposal.quorum) / 1e18
  const quorumProgress = ((forVotes + againstVotes) / quorum) * 100
  const forPercent = totalVotes > 0 ? Math.round((forVotes / totalVotes) * 100) : 0
  const againstPercent = totalVotes > 0 ? Math.round((againstVotes / totalVotes) * 100) : 0
  const abstainPercent = totalVotes > 0 ? Math.round((abstainVotes / totalVotes) * 100) : 0

  return {
    id: proposal.id,
    displayId,
    status: finalStatus,
    chain,
    title,
    description: cleanDescription,
    quorumProgress,
    timeRemaining,
    forVotes,
    quorum,
    againstVotes,
    abstainVotes,
    forPercent,
    againstPercent,
    abstainPercent,
    quorumReached: false,
    targets: proposal.targets || [],
    values: proposal.values || [],
    calldatas: proposal.calldatas || [],
    eta: proposal.eta,
    votes: proposal.votes,
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
