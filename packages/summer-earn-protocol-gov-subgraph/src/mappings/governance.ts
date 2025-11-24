import { ByteArray, Bytes, crypto, dataSource } from '@graphprotocol/graph-ts'
import {
  ProposalCanceled,
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  ProposalReceivedCrossChain,
  ProposalSentCrossChain,
  TimelockChange,
} from '../../generated/SummerGovernor/SummerGovernor'
import { CrossChainProposalByCallId } from '../../generated/schema'
import { TimelockControllerTemplate } from '../../generated/templates'

import { EventSignature } from '../constants'
import { getOrCreateCrossChainProposal, getOrCreateProposal } from '../initializers'
import { dstEidToChainIdMap, isHub } from '../utils/chain'
import { dataToTuple, getEventLogs } from '../utils/events'

export function handleTimelockChange(event: TimelockChange): void {
  TimelockControllerTemplate.create(event.params.newTimelock)
}

export function handleProposalCreated(event: ProposalCreated): void {
  if (!isHub(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.governor = event.address.toHexString()
  proposal.targets = event.params.targets.map<string>((target) => target.toHexString())
  proposal.values = event.params.values
  proposal.calldatas = event.params.calldatas
  proposal.description = event.params.description
  proposal.descriptionHash = Bytes.fromHexString(
    crypto.keccak256(ByteArray.fromUTF8(event.params.description)).toHexString(),
  )
  proposal.status = 'Pending'
  proposal.createdAt = event.block.timestamp

  proposal.save()
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  if (!isHub(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Executed'
  proposal.save()
}

export function handleProposalQueued(event: ProposalQueued): void {
  if (!isHub(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Queued'
  proposal.eta = event.params.etaSeconds
  proposal.save()
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  if (!isHub(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Canceled'
  proposal.save()
}

export function handleProposalSentCrossChain(event: ProposalSentCrossChain): void {
  if (!isHub(dataSource.network())) {
    return
  }
  const logs = getEventLogs(event, EventSignature.ProposalExecuted)
  if (logs.length > 0) {
    const log = logs[0]
    const proposalId = dataToTuple(log.data, '(uint256)')[0].toBigInt().toString()
    const proposal = getOrCreateProposal(proposalId)

    const dstEid = event.params.dstEid.toString()
    const chainId = dstEidToChainIdMap.get(dstEid)

    if (chainId) {
      let chains = proposal.chains
      if (!chains) {
        chains = []
      }
      let dstIds = proposal.dstIds
      if (!dstIds) {
        dstIds = []
      }
      dstIds.push(event.params.proposalId.toString())
      chains.push(chainId)

      proposal.chains = chains
      proposal.dstIds = dstIds
      proposal.save()
    }
  }
}

export function handleProposalReceivedCrossChain(event: ProposalReceivedCrossChain): void {
  if (isHub(dataSource.network())) {
    return
  }
  const proposal = getOrCreateCrossChainProposal(event.params.proposalId.toString())
  const logs = getEventLogs(event, EventSignature.CallSalt)
  if (logs.length > 0) {
    const log = logs[0]
    const callId = log.topics[1].toHexString()
    const proposalByCallId = new CrossChainProposalByCallId(callId)
    proposalByCallId.proposal = proposal.id
    proposalByCallId.callId = callId
    proposalByCallId.save()
  }
}
