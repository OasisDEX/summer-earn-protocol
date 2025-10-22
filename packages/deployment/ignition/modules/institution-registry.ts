import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const InstitutionRegistryModule = buildModule('InstitutionRegistryModule', (m) => {
  const owner = m.getParameter('owner', m.getAccount(0))

  const institutionalVaultRegistry = m.contract('InstitutionalVaultRegistry', [owner])

  return { institutionalVaultRegistry }
})

export type InstitutionRegistryContracts = {
  institutionalVaultRegistry: { address: string }
}
