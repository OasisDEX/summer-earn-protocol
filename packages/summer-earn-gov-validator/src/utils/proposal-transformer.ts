import { getChainNameById, HUB_CHAIN_ID } from '@/config/chains'
import {
  CrossChainProposal,
  FinalStatus,
  ProposalWithCrossChain,
  TransformedProposal,
} from '@/types/governance'

import { extractProposalMetadata } from './text'

function isExecuted(status: FinalStatus): boolean {
  return status === 'Executed' || status === 'Executed on Hub'
}

function isCanceled(status: FinalStatus): boolean {
  return status === 'Canceled'
}

export function transformProposal(
  proposalWithCrossChain: ProposalWithCrossChain,
): TransformedProposal {
  const proposal = proposalWithCrossChain.baseProposal
  // Map subgraph status to our status format

  let finalStatus: FinalStatus = proposal.status
  if (finalStatus === 'Executed' && proposalWithCrossChain.crossChainProposals.length > 0) {
    const hasPendingCrossChain = proposalWithCrossChain.crossChainProposals.some(
      (ccp: CrossChainProposal) => ccp.status !== 'Executed',
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

  // Mock voting data (would need to query vote counts from subgraph)
  const forVotes = Number(proposal.forVotes) / 1e18
  const againstVotes = Number(proposal.againstVotes) / 1e18
  const abstainVotes = Number(proposal.abstainVotes) / 1e18
  const totalVotes = forVotes + againstVotes + abstainVotes
  const quorum = Number(proposal.quorum) / 1e18
  const quorumProgress = ((forVotes + againstVotes) / quorum) * 100
  const quorumReached = quorumProgress >= 100
  const forPercent = totalVotes > 0 ? Math.round((forVotes / totalVotes) * 100) : 0
  const againstPercent = totalVotes > 0 ? Math.round((againstVotes / totalVotes) * 100) : 0
  const abstainPercent = totalVotes > 0 ? Math.round((abstainVotes / totalVotes) * 100) : 0

  if (!isExecuted(finalStatus) && !isCanceled(finalStatus)) {
    if (
      currentTimestampSeconds > voteEndSeconds &&
      ((forVotes < againstVotes && quorumReached) || !quorumReached)
    ) {
      finalStatus = 'Defeated'
    }
    if (currentTimestampSeconds >= voteStartSeconds && currentTimestampSeconds <= voteEndSeconds) {
      finalStatus = 'Active'
    }
    if (
      currentTimestampSeconds > voteEndSeconds &&
      finalStatus != 'Queued' &&
      finalStatus != 'Defeated'
    ) {
      finalStatus = 'Succeeded'
    }
  }

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
