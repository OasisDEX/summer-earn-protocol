import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createInstitutionRegistryModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const owner = m.getParameter('owner', m.getAccount(0))

    const institutionalVaultRegistry = m.contract('InstitutionalVaultRegistry', [owner])

    return { institutionalVaultRegistry }
  })
}

export type InstitutionRegistryContracts = {
  institutionalVaultRegistry: { address: string }
}
