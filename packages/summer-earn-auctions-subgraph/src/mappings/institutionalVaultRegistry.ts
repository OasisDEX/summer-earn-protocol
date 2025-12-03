import { InstitutionAdded } from '../../generated/InstitutionalVaultRegistry/InstitutionalVaultRegistry'
import { ConfigManager as ConfigManagerTemplate } from '../../generated/templates'

export function handleInstitutionAdded(event: InstitutionAdded): void {
  ConfigManagerTemplate.create(event.params.configurationManager)
}
