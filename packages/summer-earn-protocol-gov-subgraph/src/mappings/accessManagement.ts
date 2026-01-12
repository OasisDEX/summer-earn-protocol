import {
  RoleGranted,
  RoleRevoked,
} from '../../generated/ProtocolAccessManager/ProtocolAccessManager'
import { Role } from '../../generated/schema'
import { ADDRESS_ZERO, RoleAction } from '../common/constants'

import { ROLE_MAP } from '../common/hashHelpers'
import { createRoleEvent, getOrCreateRole } from '../initializers'

export function handleRoleGranted(event: RoleGranted): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.owner = event.params.account.toHexString()
  role.active = true
  role.targetContract = ADDRESS_ZERO.toHexString()
  role.accessController = event.address.toHexString()
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  if (ROLE_MAP.has(event.params.role.toHexString())) {
    role.name = ROLE_MAP.get(event.params.role.toHexString())
  } else {
    role.name = event.params.role.toHexString()
  }
  role.save()
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
