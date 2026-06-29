import { log } from '@graphprotocol/graph-ts'
import {
  RoleGranted,
  RoleRevoked,
  WhitelistOpenUpdated,
  WhitelistStatusUpdated,
} from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
import { Institution, Role, Vault } from '../../generated/schema'
import { ADDRESS_ZERO, ContractSpecificRole, RoleAction, RoleName } from '../common/constants'
import { ROLE_MAP, getContractSpecificRoleName, matchRoundsVaultRole } from '../common/hashHelpers'
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
      const maybeOperatorForFleet = getContractSpecificRoleName(
        event.params.role.toHexString(),
        ContractSpecificRole.OPERATOR_ROLE,
        vaultAddresses,
      )
      if (maybeOperatorForFleet) {
        role.name = RoleName.OPERATOR_ROLE
        role.targetContract = maybeOperatorForFleet
      }

      // Rounds vaults (input/output) also carry KEEPER/OPERATOR roles. Their
      // addresses live on each fleet's RoundsVaultPair (registered separately).
      // This resolves grants that arrive AFTER pair registration; grants that
      // land before registration are back-filled by the registry mapping.
      const roundsVaultAddresses: string[] = []
      for (let i = 0; i < vaults.length; i++) {
        const pairs = vaults[i].roundsVaultPair.load()
        for (let j = 0; j < pairs.length; j++) {
          const inputVault = pairs[j].inputVault
          if (inputVault) {
            roundsVaultAddresses.push(inputVault!)
          }
          const outputVault = pairs[j].outputVault
          if (outputVault) {
            roundsVaultAddresses.push(outputVault!)
          }
        }
      }
      if (roundsVaultAddresses.length > 0) {
        const maybeRoundsRole = matchRoundsVaultRole(
          event.params.role.toHexString(),
          roundsVaultAddresses,
        )
        if (maybeRoundsRole) {
          role.name = maybeRoundsRole.name
          role.targetContract = maybeRoundsRole.target
        }
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
  const pam = event.address.toHexString()
  const context = event.params.context.toHexString()
  const account = event.params.account.toHexString()

  const accessController = getOrCreateAccessController(pam)
  const id = `${pam}-${context}-${account}`

  const role = getOrCreateRole(id)
  role.owner = account
  role.name = RoleName.WHITELIST_ROLE
  role.targetContract = context
  role.accessController = pam
  role.createdTimestamp = event.block.timestamp
  role.createdBlockNumber = event.block.number
  role.institution = accessController.institution
  role.active = event.params.isWhitelisted
  role.save()

  createRoleEvent(
    event,
    event.params.isWhitelisted ? RoleAction.GRANT_ROLE : RoleAction.REVOKE_ROLE,
    role.id,
    accessController.institution,
  )
}

export function handleWhitelistOpenUpdated(event: WhitelistOpenUpdated): void {
  const context = event.params.context.toHexString()
  const vault = Vault.load(context)
  if (vault == null) {
    log.warning('WhitelistOpenUpdated for unknown vault {}', [context])
    return
  }
  vault.isWhitelistOpen = event.params.isOpen
  vault.save()
}
