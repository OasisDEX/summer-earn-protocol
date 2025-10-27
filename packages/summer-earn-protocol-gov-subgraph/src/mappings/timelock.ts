import { dataSource } from '@graphprotocol/graph-ts'
import { CrossChainProposalByCallId } from '../../generated/schema'
import {
  CallExecuted,
  CallSalt,
  CallScheduled,
} from '../../generated/templates/TimelockControllerTemplate/SummerTimelockController'
import { getOrCreateCrossChainProposal } from '../initializers'
import { isHub } from '../utils/chain'

export function handleCallSalt(event: CallSalt): void {
  if (isHub(dataSource.network())) {
    return
  }
  const callId = event.params.id.toHexString()
  const proposalIdEntity = CrossChainProposalByCallId.load(callId)
  if (proposalIdEntity) {
    const proposal = getOrCreateCrossChainProposal(proposalIdEntity.proposal)
    proposal.salt = event.params.salt
    proposal.save()
  }
}

export function handleCallExecuted(event: CallExecuted): void {
  if (isHub(dataSource.network())) {
    return
  }
  const callId = event.params.id.toHexString()
  const proposalIdEntity = CrossChainProposalByCallId.load(callId)
  if (proposalIdEntity) {
    const proposal = getOrCreateCrossChainProposal(proposalIdEntity.proposal)
    proposal.status = 'Executed'
    proposal.save()
  }
}

export function handleCallScheduled(event: CallScheduled): void {
  if (isHub(dataSource.network())) {
    return
  }
  const callId = event.params.id.toHexString()
  const proposalIdEntity = CrossChainProposalByCallId.load(callId)
  if (proposalIdEntity) {
    const proposal = getOrCreateCrossChainProposal(proposalIdEntity.proposal)

    const calldatas = proposal.calldatas
    calldatas.push(event.params.data)
    proposal.calldatas = calldatas

    const targets = proposal.targets
    targets.push(event.params.target.toHexString())
    proposal.targets = targets

    const values = proposal.values
    values.push(event.params.value)
    proposal.values = values

    proposal.eta = event.block.timestamp.plus(event.params.delay)

    proposal.save()
  }
}
