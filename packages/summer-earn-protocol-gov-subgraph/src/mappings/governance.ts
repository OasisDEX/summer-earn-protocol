import { BigInt, ByteArray, Bytes, crypto, dataSource } from '@graphprotocol/graph-ts'
import {
  ProposalCanceled,
  ProposalCreated,
  ProposalExecuted,
  ProposalQueued,
  ProposalSentCrossChain,
  TimelockChange,
} from '../../generated/SummerGovernor/SummerGovernor'
import { Proposal } from '../../generated/schema'
import { TimelockControllerTemplate } from '../../generated/templates'
import { isBase } from './timelock'

// Create a map of dstEid to chainId
const dstEidToChainIdMap = new Map<string, string>()
dstEidToChainIdMap.set('30101', '1') // Ethereum Mainnet
dstEidToChainIdMap.set('30110', '42161') // Arbitrum
dstEidToChainIdMap.set('30184', '8453') // Base
dstEidToChainIdMap.set('30332', '146') // Sonic

export const subgraphNetworkToChainIdMap = new Map<string, string>()
subgraphNetworkToChainIdMap.set('mainnet', '1')
subgraphNetworkToChainIdMap.set('arbitrum-one', '42161')
subgraphNetworkToChainIdMap.set('base', '8453')
subgraphNetworkToChainIdMap.set('sonic-mainnet', '146')

export function handleTimelockChange(event: TimelockChange): void {
  TimelockControllerTemplate.create(event.params.newTimelock)
}

export function handleProposalCreated(event: ProposalCreated): void {
  if (!isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.targets = event.params.targets.map<string>((target) => target.toHexString())
  proposal.values = event.params.values
  proposal.calldatas = event.params.calldatas
  proposal.description = event.params.description
  proposal.descriptionHash = Bytes.fromHexString(
    crypto.keccak256(ByteArray.fromUTF8(event.params.description)).toHexString(),
  )
  proposal.status = 'Pending'

  proposal.save()
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  if (!isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Executed'
  proposal.save()
}

export function handleProposalQueued(event: ProposalQueued): void {
  if (!isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Queued'
  proposal.eta = event.params.etaSeconds
  proposal.save()
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  if (!isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
  proposal.status = 'Canceled'
  proposal.save()
}

export function handleProposalSentCrossChain(event: ProposalSentCrossChain): void {
  if (!isBase(dataSource.network())) {
    return
  }
  const proposal = getOrCreateProposal(event.params.proposalId.toString())
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
    dstIds.push(dstEid)
    chains.push(chainId)

    proposal.chains = chains
    proposal.dstIds = dstIds
    proposal.save()
  }
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
    proposal.status = 'Pending'
    proposal.description = ''
    proposal.descriptionHash = Bytes.fromHexString('')
  }
  return proposal
}
