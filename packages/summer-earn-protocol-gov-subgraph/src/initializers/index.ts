import { BigInt, Bytes, dataSource, ethereum } from '@graphprotocol/graph-ts'
import { CrossChainProposal, Proposal, Role, RoleEvent } from '../../generated/schema'
import { subgraphNetworkToChainIdMap } from '../utils/chain'
import { RoleAction } from '../common/constants'

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

export function getOrCreateRole(id: string): Role {
  let role = Role.load(id)
  if (!role) {
    role = new Role(id)
  }
  return role
}

export function createRoleEvent(event: ethereum.Event, action: string, roleId: string): RoleEvent {
  const roleEvent = new RoleEvent(
    event.receipt!.transactionHash.toHexString() + '--' + event.logIndex.toString(),
  )
  roleEvent.hash = event.receipt!.transactionHash.toHexString()
  roleEvent.logIndex = event.logIndex.toI32()
  roleEvent.timestamp = event.block.timestamp
  roleEvent.blockNumber = event.block.number
  roleEvent.caller = event.transaction.from.toHexString()
  roleEvent.action = action
  roleEvent.role = roleId
  roleEvent.save()
  return roleEvent
}
