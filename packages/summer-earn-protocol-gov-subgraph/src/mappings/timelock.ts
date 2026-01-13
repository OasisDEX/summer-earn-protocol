import { dataSource } from '@graphprotocol/graph-ts'
import { CrossChainProposalByCallId, Role } from '../../generated/schema'
import {
  CallExecuted,
  CallSalt,
  CallScheduled,
  RoleGranted,
  RoleRevoked,
} from '../../generated/templates/TimelockControllerTemplate/SummerTimelockController'
import { ADDRESS_ZERO, RoleAction } from '../common/constants'
import { ROLE_MAP } from '../common/hashHelpers'
import { createRoleEvent, getOrCreateRole, getOrCreateCrossChainProposal } from '../initializers'
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

export function handleTimelockRoleGranted(event: RoleGranted): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.owner = event.params.account.toHexString()
  role.active = true
  role.name = event.params.role.toHexString()
  role.targetContract = ADDRESS_ZERO.toHexString()
  role.accessController = event.address.toHexString()
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number

  // Map role hash to role name for TimelockController roles
  if (ROLE_MAP.has(event.params.role.toHexString())) {
    role.name = ROLE_MAP.get(event.params.role.toHexString())
  }

  role.save()

  createRoleEvent(event, RoleAction.GRANT_ROLE, role.id)
}

export function handleTimelockRoleRevoked(event: RoleRevoked): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`

  const role = Role.load(id)
  if (role) {
    role.active = false
    role.save()

    createRoleEvent(event, RoleAction.REVOKE_ROLE, role.id)
  }
}
