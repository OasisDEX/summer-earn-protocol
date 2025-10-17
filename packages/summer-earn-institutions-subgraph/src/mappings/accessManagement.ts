import {
  RoleGranted,
  RoleRevoked,
} from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
import { Role } from '../../generated/schema'

function handleRoleGranted(event: RoleGranted): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.name = event.params.role.toString()
  role.accessController = event.address.toHexString()
  role.role = 'ALLOWED'
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = event.address.toHexString()
  role.save()
}

function handleRoleRevoked(event: RoleRevoked): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.name = event.params.role.toString()
  role.accessController = event.address.toHexString()
  role.role = 'NOT_ALLOWED'
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = event.address.toHexString()
  role.save()
}

export function getOrCreateRole(id: string): Role {
  let role = Role.load(id)
  if (!role) {
    role = new Role(id)
  }
  return role
}
