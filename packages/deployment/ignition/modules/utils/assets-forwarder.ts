import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export function createAssetsForwarderModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const accessManager = m.getParameter<string>('accessManager')

    const assetsForwarder = m.contract('AssetsForwarder', [accessManager])

    return { assetsForwarder }
  })
}
