import { store } from '@graphprotocol/graph-ts'
import { HarborCommand } from '../../generated/HarborCommand/HarborCommand'
import { ConfigurationManager } from '../../generated/InstitutionalVaultRegistry/ConfigurationManager'
import {
  InstitutionAdded,
  InstitutionAdmiralsQuartersUpdated,
  InstitutionRemoved,
} from '../../generated/InstitutionalVaultRegistry/InstitutionalVaultRegistry'
import { Institution } from '../../generated/schema'
import {
  AdmiralsQuarters as AdmiralsQuartersTemplate,
  HarborCommand as HarborCommandTemplate,
  ProtocolAccessManager as ProtocolAccessManagerTemplate,
} from '../../generated/templates'
import {
  getOrCreateAccessController,
  getOrCreateVault,
  getOrCreateYieldAggregator,
} from '../common/initializers'

export function handleInstitutionAdded(event: InstitutionAdded): void {
  let institution = new Institution(event.params.id.toHex())
  const harborCommand = ConfigurationManager.bind(event.params.configurationManager).harborCommand()
  HarborCommandTemplate.create(harborCommand)
  institution.protocolAccessManager = event.params.protocolAccessManager.toHexString()
  ProtocolAccessManagerTemplate.create(event.params.protocolAccessManager)
  institution.admiralsQuarters = event.params.admiralsQuarters.toHexString()
  AdmiralsQuartersTemplate.create(event.params.admiralsQuarters)
  getOrCreateAccessController(harborCommand.toHexString(), institution.id)
  getOrCreateAccessController(event.params.protocolAccessManager.toHexString(), institution.id)
  getOrCreateAccessController(event.params.admiralsQuarters.toHexString(), institution.id)
  institution.harborCommand = harborCommand.toHexString()
  institution.configurationManager = event.params.configurationManager.toHexString()
  institution.createdTimestamp = event.block.timestamp
  institution.createdBlockNumber = event.block.number
  institution.active = true
  institution.save()

  const harborCommandEntity = HarborCommand.bind(harborCommand)
  const maybeFleets = harborCommandEntity.try_getActiveFleetCommanders()
  if (maybeFleets.reverted) {
    return
  }
  const fleets = maybeFleets.value
  for (let i = 0; i < fleets.length; i++) {
    const fleet = fleets[i]
    getOrCreateVault(fleet, event.block, institution.id)
  }
}

export function handleInstitutionAdmiralsQuartersUpdated(
  event: InstitutionAdmiralsQuartersUpdated,
): void {
  let institution = new Institution(event.params.id.toHex())
  institution.admiralsQuarters = event.params.newAdmiralsQuarters.toHexString()
  getOrCreateAccessController(event.params.newAdmiralsQuarters.toHexString())
  institution.save()
}

export function handleInstitutionRemoved(event: InstitutionRemoved): void {
  let institution = Institution.load(event.params.id.toHex())
  if (!institution) {
    return
  }

  let protocol = getOrCreateYieldAggregator(event.block.timestamp)
  if (!protocol) {
    return
  }
  const roles = institution.roles.load()
  for (let i = 0; i < roles.length; i++) {
    const role = roles[i]
    const events = role.events.load()
    for (let j = 0; j < events.length; j++) {
      const event = events[j]
      store.remove('RoleEvent', event.id)
    }
    store.remove('Role', role.id)
  }
  const vaults = institution.vaults.load()

  for (let i = 0; i < vaults.length; i++) {
    const vault = vaults[i]
    const positions = vault.positions
    for (let j = 0; j < positions.length; j++) {
      const position = positions[j]
      store.remove('Position', position)
    }
    const arks = vault.arks.load()
    for (let j = 0; j < arks.length; j++) {
      const ark = arks[j]
      store.remove('Ark', ark.id)
    }
    store.remove('Vault', vault.id)
  }
  protocol.save()
  store.remove('Institution', institution.id)
}
