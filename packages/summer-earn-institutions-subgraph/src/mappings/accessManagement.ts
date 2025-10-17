import {
  RoleGranted,
  RoleRevoked,
} from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
import { WhitelistStatusUpdated } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { getOrCreateAccessController, getOrCreateRole } from '../common/initializers'

export function handleRoleGranted(event: RoleGranted): void {
  const accessController = getOrCreateAccessController(event.address.toHexString())
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.name = event.params.role.toString()
  role.accessController = event.address.toHexString()
  role.role = 'ALLOWED'
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = accessController.institution
  role.save()
}

export function handleRoleRevoked(event: RoleRevoked): void {
  const accessController = getOrCreateAccessController(event.address.toHexString())
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.name = event.params.role.toString()
  role.accessController = event.address.toHexString()
  role.role = 'NOT_ALLOWED'
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = accessController.institution
  role.save()
}

export function handleWhitelistStatusUpdated(event: WhitelistStatusUpdated): void {
  const accessController = getOrCreateAccessController(event.address.toHexString())
  // role id is: fleetAddress-accountAddress
  const id = `${event.address.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)

  role.name = 'Whitelist'
  role.accessController = event.address.toHexString()
  role.role = event.params.allowed ? 'ALLOWED' : 'NOT_ALLOWED'
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = accessController.institution
  role.save()
}
