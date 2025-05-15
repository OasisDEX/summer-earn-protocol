import { Proposal } from '../../generated/schema'
import { ProposalCanceled, ProposalCreated, ProposalExecuted, ProposalQueued, ProposalSentCrossChain } from '../../generated/SummerGovernor/SummerGovernor'
import { Address, ByteArray, Bytes, crypto } from '@graphprotocol/graph-ts'

// Create a map of dstEid to chainId
const dstEidToChainIdMap = new Map<string, string>()
dstEidToChainIdMap.set('30101', '1') // Ethereum Mainnet
dstEidToChainIdMap.set('30110', '42161') // Arbitrum
dstEidToChainIdMap.set('30184', '8453') // Base
dstEidToChainIdMap.set('30332', '11155111') // Sonic

export function handleProposalCreated(event: ProposalCreated): void {
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.targets = event.params.targets.map<string>((target) => target.toHexString())
  proposal.values = event.params.values
  proposal.calldatas = event.params.calldatas
  proposal.description = event.params.description
  proposal.descriptionHash = Bytes.fromHexString(crypto.keccak256(ByteArray.fromUTF8(event.params.description)).toHexString())
  proposal.status = 'Pending'
  proposal.chains = []
  proposal.save()
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Executed'
  proposal.save()
}

export function handleProposalQueued(event: ProposalQueued): void {
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Queued'
  proposal.save()
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Canceled'
  proposal.save()
}

export function handleProposalSentCrossChain(event: ProposalSentCrossChain): void {
  // const proposal = getOrCreateProposal(event.params.proposalId.toString())
  // const dstEid = event.params.dstEid.toString()
  // const chainId = dstEidToChainIdMap.get(dstEid)
  
  // if (chainId) {
  //   let chains = proposal.chains
  //   if (!chains) {
  //     chains = []
  //   }
  //   chains.push(chainId)
  //   proposal.chains = chains
  //   proposal.save()
  // }
}

export function getOrCreateProposal(proposalId: string): Proposal {
  let proposal = Proposal.load(proposalId)
  if (!proposal) {
    proposal = new Proposal(proposalId)
    proposal.chains = []
  }
  return proposal
}