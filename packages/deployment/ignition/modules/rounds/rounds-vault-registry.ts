import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createRoundsVaultRegistryModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const accessManager = m.getParameter<string>('accessManager')

    const roundsVaultRegistry = m.contract('RoundsVaultRegistry', [accessManager])

    return { roundsVaultRegistry }
  })
}
