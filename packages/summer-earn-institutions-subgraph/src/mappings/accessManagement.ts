import { store } from '@graphprotocol/graph-ts'
import {
  RoleGranted,
  RoleRevoked,
} from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
import { Institution } from '../../generated/schema'
import { WhitelistStatusUpdated } from '../../generated/templates/FleetCommanderTemplate/FleetCommander'
import { ContractSpecificRole, ROLE_MAP, getContractSpecificRoleName } from '../common/hashHelpers'
import { getOrCreateAccessController, getOrCreateRole } from '../common/initializers'

export function handleRoleGranted(event: RoleGranted): void {
  const accessController = getOrCreateAccessController(event.address.toHexString())
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  const role = getOrCreateRole(id)
  role.name = event.params.role.toHexString()
  role.accessController = event.address.toHexString()
  role.role = 'ALLOWED'
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = accessController.institution
  const institution = Institution.load(accessController.institution)
  if (ROLE_MAP.has(event.params.role.toHexString())) {
    // if its a static role return early
    role.name = ROLE_MAP.get(event.params.role.toHexString())
  } else {
    if (institution != null) {
      role.save()
    }
    const vaults = institution!.vaults.load()
    if (vaults) {
      const vaultAddresses = vaults.map<string>((vault) => vault.id)
      const maybeCuratorForFleet = getContractSpecificRoleName(
        event.params.role.toHexString(),
        ContractSpecificRole.CURATOR_ROLE,
        vaultAddresses,
      )
      if (maybeCuratorForFleet) {
        role.name = `CURATOR_ROLE_` + maybeCuratorForFleet
      }
      const maybeKeeperForFleet = getContractSpecificRoleName(
        event.params.role.toHexString(),
        ContractSpecificRole.KEEPER_ROLE,
        vaultAddresses,
      )
      if (maybeKeeperForFleet) {
        role.name = `KEEPER_ROLE_` + maybeKeeperForFleet
      }
    }
  }
  role.save()
}

export function handleRoleRevoked(event: RoleRevoked): void {
  const id = `${event.address.toHexString()}-${event.params.role.toHexString()}-${event.params.account.toHexString()}`
  store.remove('Role', id)
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
