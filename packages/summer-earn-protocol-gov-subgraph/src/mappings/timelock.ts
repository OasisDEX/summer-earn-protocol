import { Bytes, dataSource } from '@graphprotocol/graph-ts'
import { CrossChainProposal } from '../../generated/schema'
import {
  CallExecuted,
  CallSalt,
  CallScheduled,
} from '../../generated/templates/TimelockControllerTemplate/SummerTimelockController'
import { subgraphNetworkToChainIdMap } from './governance'

export function isBase(netowrk: string): boolean {
  return netowrk === 'base'
}

export function handleCallSalt(event: CallSalt): void {
  if (isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateCrossChainProposal(event.params.id.toHexString())
  proposal.salt = event.params.salt
  proposal.save()
}

export function handleCallExecuted(event: CallExecuted): void {
  if (isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateCrossChainProposal(event.params.id.toHexString())
  proposal.status = 'Executed'
  proposal.save()
}

export function handleCallScheduled(event: CallScheduled): void {
  if (isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateCrossChainProposal(event.params.id.toHexString())

  const calldatas = proposal.calldatas
  calldatas.push(event.params.data)
  proposal.calldatas = calldatas

  const targets = proposal.targets
  targets.push(event.params.target.toHexString())
  proposal.targets = targets

  const values = proposal.values
  values.push(event.params.value)
  proposal.values = values

  proposal.save()
}

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
  }
  return proposal
}
