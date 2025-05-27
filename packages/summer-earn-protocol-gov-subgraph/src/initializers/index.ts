import { BigInt, Bytes, dataSource } from '@graphprotocol/graph-ts'
import { CrossChainProposal, Proposal } from '../../generated/schema'
import { subgraphNetworkToChainIdMap } from '../utils/chain'

export function getOrCreateCrossChainProposal(proposalId: string): CrossChainProposal {
  let proposal = CrossChainProposal.load(proposalId)
  if (!proposal) {
    proposal = new CrossChainProposal(proposalId)
    proposal.proposalId = proposalId
    proposal.chainId = subgraphNetworkToChainIdMap.get(dataSource.network())
    proposal.salt = Bytes.fromHexString('')
    proposal.status = 'Pending'
    proposal.targets = []
    proposal.values = []
    proposal.calldatas = []
    proposal.eta = BigInt.fromI32(0)
    proposal.save()
  }
  return proposal
}

export function getOrCreateProposal(proposalId: string): Proposal {
  let proposal = Proposal.load(proposalId)
  if (!proposal) {
    proposal = new Proposal(proposalId)
    proposal.chains = []
    proposal.eta = BigInt.fromI32(0)
    proposal.dstIds = []
    proposal.chains = []
    proposal.targets = []
    proposal.values = []
    proposal.calldatas = []
    proposal.description = ''
    proposal.descriptionHash = Bytes.fromHexString('')
  }
  return proposal
}
