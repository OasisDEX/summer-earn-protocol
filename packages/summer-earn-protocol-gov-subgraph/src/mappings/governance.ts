import { BigInt, ByteArray, Bytes, crypto, dataSource } from '@graphprotocol/graph-ts'
import {
  ProposalCanceled,
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  ProposalReceivedCrossChain,
  ProposalSentCrossChain,
  SummerGovernor,
  TimelockChange,
  VoteCast,
  VoteCastWithParams,
} from '../../generated/SummerGovernor/SummerGovernor'
import { CrossChainProposalByCallId, Vote } from '../../generated/schema'
import { TimelockControllerTemplate } from '../../generated/templates'

import { BigIntOne, EventSignature } from '../constants'
import {
  getOrCreateCrossChainProposal,
  getOrCreateDelegate,
  getOrCreateProposal,
} from '../initializers'
import { dstEidToChainIdMap, isHub } from '../utils/chain'
import { dataToTuple, getEventLogs } from '../utils/events'

function isGovernorV2(address: string): boolean {
  return address.toLowerCase() == '0x4cEeE1b6289624d381383C1Bb42B118d5f2c3274'.toLowerCase()
}

export function handleTimelockChange(event: TimelockChange): void {
  TimelockControllerTemplate.create(event.params.newTimelock)
}

export function handleProposalCreated(event: ProposalCreated): void {
  if (!isHub(dataSource.network())) {
    return
  }

  if (!isGovernorV2(event.address.toHexString())) {
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

  const governor = SummerGovernor.bind(event.address)
  proposal.quorum = governor.quorum(event.block.timestamp.minus(BigIntOne))

  proposal.save()
}

enum VoteType {
  VoteAgainst = 0,
  VoteFor = 1,
  VoteAbstain = 2,
}

export function handleVoteCast(event: VoteCast): void {
  if (!isHub(dataSource.network())) {
    return
  }
  if (!isGovernorV2(event.address.toHexString())) {
    return
  }
  const proposalId = event.params.proposalId.toString()
  const proposal = getOrCreateProposal(proposalId)

  const voteId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  const vote = new Vote(voteId)
  vote.proposal = proposal.id
  vote.voter = event.params.voter.toHexString()
  vote.support = event.params.support
  vote.weight = event.params.weight
  vote.reason = event.params.reason
  vote.blockNumber = event.block.number
  vote.timestamp = event.block.timestamp
  vote.save()

  const delegate = getOrCreateDelegate(event.params.voter.toHexString())

  if (event.params.support == VoteType.VoteAgainst) {
    proposal.againstVotes = proposal.againstVotes.plus(delegate.votingPower)
  } else if (event.params.support == VoteType.VoteFor) {
    proposal.forVotes = proposal.forVotes.plus(delegate.votingPower)
  } else if (event.params.support == VoteType.VoteAbstain) {
    proposal.abstainVotes = proposal.abstainVotes.plus(delegate.votingPower)
  }
  proposal.save()
}

export function handleVoteCastWithParams(event: VoteCastWithParams): void {
  if (!isHub(dataSource.network())) {
    return
  }
  if (!isGovernorV2(event.address.toHexString())) {
    return
  }
  const proposalId = event.params.proposalId.toString()
  const proposal = getOrCreateProposal(proposalId)

  const voteId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  const vote = new Vote(voteId)
  vote.proposal = proposal.id
  vote.voter = event.params.voter.toHexString()
  vote.support = event.params.support
  vote.weight = event.params.weight
  vote.reason = event.params.reason
  vote.params = event.params.params
  vote.blockNumber = event.block.number
  vote.timestamp = event.block.timestamp
  vote.save()

  const delegate = getOrCreateDelegate(event.params.voter.toHexString())

  if (event.params.support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(delegate.votingPower)
  } else if (event.params.support == 1) {
    proposal.forVotes = proposal.forVotes.plus(delegate.votingPower)
  } else if (event.params.support == 2) {
    proposal.abstainVotes = proposal.abstainVotes.plus(delegate.votingPower)
  }
  proposal.save()
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  if (!isHub(dataSource.network())) {
    return
  }
  if (!isGovernorV2(event.address.toHexString())) {
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
  if (!isGovernorV2(event.address.toHexString())) {
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
  if (!isGovernorV2(event.address.toHexString())) {
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
  if (!isGovernorV2(event.address.toHexString())) {
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
