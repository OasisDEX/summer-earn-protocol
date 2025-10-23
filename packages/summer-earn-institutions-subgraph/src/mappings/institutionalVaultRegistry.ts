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
import { getOrCreateAccessController, getOrCreateVault } from '../common/initializers'

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
  let institution = new Institution(event.params.id.toHex())
  institution.active = false
  institution.save()
}
