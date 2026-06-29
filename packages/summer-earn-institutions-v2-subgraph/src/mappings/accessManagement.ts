import { log } from '@graphprotocol/graph-ts'
import {
  RoleGranted,
  RoleRevoked,
  WhitelistOpenUpdated,
  WhitelistStatusUpdated,
} from '../../generated/InstitutionalVaultRegistry/ProtocolAccessManager'
import { Institution, Role, Vault } from '../../generated/schema'
import { ADDRESS_ZERO, RoleAction, RoleName } from '../common/constants'
import {
  ARK_ROLE_SPECS,
  FLEET_ROLE_SPECS,
  ROLE_MAP,
  ROUNDS_VAULT_ROLE_SPECS,
  matchContractSpecificRole,
} from '../common/hashHelpers'
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
  } else if (institution != null) {
    const roleHash = event.params.role.toHexString()
    const vaults = institution.vaults.load()
    const vaultAddresses = vaults.map<string>((vault) => vault.id)

    // FleetCommander CURATOR/KEEPER/OPERATOR.
    const fleetMatch = matchContractSpecificRole(roleHash, vaultAddresses, FLEET_ROLE_SPECS)
    if (fleetMatch != null) {
      role.name = fleetMatch.name
      role.targetContract = fleetMatch.target
    } else {
      // Rounds vaults (input/output) also carry KEEPER/OPERATOR roles; their
      // addresses live on each fleet's RoundsVaultPair (registered separately).
      // Resolves grants that arrive AFTER pair registration; earlier grants are
      // back-filled by the registry mapping.
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
      const roundsMatch = matchContractSpecificRole(
        roleHash,
        roundsVaultAddresses,
        ROUNDS_VAULT_ROLE_SPECS,
      )
      if (roundsMatch != null) {
        role.name = roundsMatch.name
        role.targetContract = roundsMatch.target
      } else {
        // Arks carry COMMANDER, granted to the fleet. Resolves grants that arrive
        // when the ark is already known to the subgraph (e.g. just after enlist);
        // grants that land before the ark is known are back-filled at enlist
        // bootstrap / handleArkAdded. targetContract is the fleet (the grantee),
        // by design — mirroring how CURATOR is stored against the fleet.
        const arkAddresses: string[] = []
        for (let i = 0; i < vaults.length; i++) {
          const arks = vaults[i].arks.load()
          for (let j = 0; j < arks.length; j++) {
            arkAddresses.push(arks[j].id)
          }
        }
        const arkMatch = matchContractSpecificRole(roleHash, arkAddresses, ARK_ROLE_SPECS)
        if (arkMatch != null) {
          role.name = arkMatch.name
          role.targetContract = event.params.account.toHexString()
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
