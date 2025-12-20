import { store } from '@graphprotocol/graph-ts'
import {
  RoleGranted,
  RoleRevoked,
} from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
import { Institution, Role } from '../../generated/schema'
import { WhitelistStatusUpdated } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { ADDRESS_ZERO, ContractSpecificRole, RoleAction, RoleName } from '../common/constants'
import { ROLE_MAP, getContractSpecificRoleName } from '../common/hashHelpers'
import {
  createRoleEvent,
  getOrCreateAccessController,
  getOrCreateRole,
} from '../common/initializers'

export function handleRoleGranted(event: RoleGranted): void {
  const accessController = getOrCreateAccessController(event.address.toHexString())
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.owner = event.params.account.toHexString()
  role.active = true
  role.name = event.params.role.toHexString()
  role.targetContract = ADDRESS_ZERO.toHexString()
  role.accessController = event.address.toHexString()
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = accessController.institution
  const institution = Institution.load(accessController.institution)
  if (ROLE_MAP.has(event.params.role.toHexString())) {
    // if its a static role return early
    role.name = ROLE_MAP.get(event.params.role.toHexString())
  } else {
    const vaults = institution!.vaults.load()
    if (vaults) {
      const vaultAddresses = vaults.map<string>((vault) => vault.id)
      const maybeCuratorForFleet = getContractSpecificRoleName(
        event.params.role.toHexString(),
        ContractSpecificRole.CURATOR_ROLE,
        vaultAddresses,
      )
      if (maybeCuratorForFleet) {
        role.name = RoleName.CURATOR_ROLE
        role.targetContract = maybeCuratorForFleet
      }
      const maybeKeeperForFleet = getContractSpecificRoleName(
        event.params.role.toHexString(),
        ContractSpecificRole.KEEPER_ROLE,
        vaultAddresses,
      )
      if (maybeKeeperForFleet) {
        role.name = RoleName.KEEPER_ROLE
        role.targetContract = maybeKeeperForFleet
      }
    }
  }
  role.save()

  createRoleEvent(event, RoleAction.GRANT_ROLE, role.id, accessController.institution)
}

export function handleRoleRevoked(event: RoleRevoked): void {
  const accessController = getOrCreateAccessController(event.address.toHexString())
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`

  const role = Role.load(id)
  if (role) {
    role.active = false
    role.save()

    createRoleEvent(event, RoleAction.REVOKE_ROLE, role.id, accessController.institution)
  }
}

export function handleWhitelistStatusUpdated(event: WhitelistStatusUpdated): void {
  const accessController = getOrCreateAccessController(event.address.toHexString())
  // role id is: fleetAddress-accountAddress
  const id = `${event.address.toHexString()}-${event.params.account.toHexString()}`

  const role = getOrCreateRole(id)
  role.owner = event.params.account.toHexString()
  role.name = RoleName.WHITELIST_ROLE
  role.targetContract = event.address.toHexString()
  role.accessController = event.address.toHexString()
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = accessController.institution
  role.active = event.params.allowed
  role.save()

  createRoleEvent(
    event,
    event.params.allowed ? RoleAction.GRANT_ROLE : RoleAction.REVOKE_ROLE,
    role.id,
    accessController.institution,
  )
}
