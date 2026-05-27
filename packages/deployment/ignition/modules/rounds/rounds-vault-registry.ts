import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createRoundsVaultRegistryModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const owner = m.getParameter<string>('owner')

    const roundsVaultRegistry = m.contract('RoundsVaultRegistry', [owner])

    return { roundsVaultRegistry }
  })
}
