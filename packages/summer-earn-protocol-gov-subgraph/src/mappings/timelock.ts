import { ByteArray, Bytes, crypto, dataSource, ethereum } from '@graphprotocol/graph-ts'
import { CrossChainProposal, CrossChainProposalByCallId } from '../../generated/schema'
import {
  CallExecuted,
  CallSalt,
  CallScheduled,
} from '../../generated/templates/TimelockControllerTemplate/SummerTimelockController'
import { subgraphNetworkToChainIdMap } from './governance'

export function isBase(netowrk: string): boolean {
  return netowrk == 'base'
}

export function handleCallSalt(event: CallSalt): void {
  if (isBase(dataSource.network())) {
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
  if (isBase(dataSource.network())) {
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
  if (isBase(dataSource.network())) {
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

    proposal.save()
  }
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
    proposal.save()
  }
  return proposal
}

/**
 * @dev Retrieves the event signature hash for a given event name string.
 * @param eventSig The name of the event to retrieve the signature hash for.
 * @returns A byte array representing the keccak256 hash of the event signature.
 */
export function getTopic0(eventSig: string): ByteArray {
  const signature = ByteArray.fromUTF8(eventSig)

  return crypto.keccak256(signature)
}

export class EventSignature {
  // EARN
  static ProposalReceivedCrossChain: string = 'ProposalReceivedCrossChain(uint256,uint32)'
  static CallSalt: string = 'CallSalt(bytes32,bytes32)'
  static ProposalExecuted: string = 'ProposalExecuted(uint256)'
}

let topic0: ByteArray
let _log: ethereum.Log
/**
 * @dev Retrieves an array of all logs matching a particular event name.
 * @param event The Ethereum event object to retrieve logs from.
 * @param eventName The name of the event to filter for.
 * @returns An array of Ethereum log objects that match the specified event name.
 */
export function getEventLogs(event: ethereum.Event, eventName: string): ethereum.Log[] {
  const receipt = event.receipt
  if (receipt == null) {
    return []
  }
  topic0 = getTopic0(eventName)

  return receipt.logs.filter((log) => {
    _log = log;
    if(_log.topics.length === 0) {
      return false;
    }
    return log.topics[0].equals(topic0);
  })
}
