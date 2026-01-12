import { Address } from '@graphprotocol/graph-ts'
import {
  GrantContractSpecificRoleCall,
  RoleGranted,
  RoleRevoked,
} from '../../generated/ProtocolAccessManager/ProtocolAccessManager'
import { Role } from '../../generated/schema'
import { ADDRESS_ZERO, ContractSpecificRole, RoleAction, RoleName } from '../common/constants'

import {
  ROLE_MAP,
  generateContractSpecificRole,
  getContractSpecificRoleName,
} from '../common/hashHelpers'
import { createRoleEvent, getOrCreateRole } from '../initializers'

export function handleRoleGranted(event: RoleGranted): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`

  if (ROLE_MAP.has(event.params.role.toHexString())) {
    const role = getOrCreateRole(id)
    role.owner = event.params.account.toHexString()
    role.active = true
    role.targetContract = ADDRESS_ZERO.toHexString()
    role.accessController = event.address.toHexString()
    role.createdTimestamp = event.block.timestamp
    role.createdBlockNumber = event.block.number
    // if its a static role, set the name and return early
    role.name = ROLE_MAP.get(event.params.role.toHexString())
    role.save()
  }

  createRoleEvent(event, RoleAction.GRANT_ROLE, id)
}

export function handleRoleRevoked(event: RoleRevoked): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`

  const role = Role.load(id)
  if (role) {
    role.active = false
    role.save()

    createRoleEvent(event, RoleAction.REVOKE_ROLE, role.id)
  }
}

export function handleGrantContractSpecificRole(call: GrantContractSpecificRoleCall): void {
  const roleBytes = generateContractSpecificRole(
    call.inputs.roleName,
    call.inputs.roleTargetContract.toHexString(),
  )
  const id = `${call.to.toHexString()}-${roleBytes}-${call.inputs.roleOwner.toHexString()}`
  const role = getOrCreateRole(id)
  role.owner = call.inputs.roleOwner.toHexString()
  role.active = true
  role.name = getContractSpecificRoleName(call.inputs.roleName as ContractSpecificRole)
  role.targetContract = call.inputs.roleTargetContract.toHexString()
  role.accessController = call.to.toHexString()
  role.save()
}
