import { HarborCommand } from '../../generated/HarborCommand/HarborCommand'
import { ConfigurationManager } from '../../generated/InstitutionalVaultRegistry/ConfigurationManager'
import {
  InstitutionAdded,
  InstitutionAdmiralsQuartersUpdated,
  InstitutionDisabled,
} from '../../generated/InstitutionalVaultRegistry/InstitutionalVaultRegistry'
import { Institution } from '../../generated/schema'
import { HarborCommand as HarborCommandTemplate } from '../../generated/templates'
import { getOrCreateVault } from '../common/initializers'

export function handleInstitutionAdded(event: InstitutionAdded): void {
  let institution = new Institution(event.params.id.toHex())
  const harborCommand = ConfigurationManager.bind(event.params.configurationManager).harborCommand()
  HarborCommandTemplate.create(harborCommand)
  institution.protocolAccessManager = event.params.protocolAccessManager.toHexString()
  institution.admiralsQuarters = event.params.admiralsQuarters.toHexString()
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
    getOrCreateVault(fleet, event.block)
  }
}

export function handleInstitutionAdmiralsQuartersUpdated(
  event: InstitutionAdmiralsQuartersUpdated,
): void {
  let institution = new Institution(event.params.id.toHex())
  institution.admiralsQuarters = event.params.newAdmiralsQuarters.toHexString()
  institution.save()
}

export function handleInstitutionDisabled(event: InstitutionDisabled): void {
  let institution = new Institution(event.params.id.toHex())
  institution.active = false
  institution.save()
}
