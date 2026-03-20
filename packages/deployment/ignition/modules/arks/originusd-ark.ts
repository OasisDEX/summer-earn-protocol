import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Ignition module to deploy OriginUSDArk.
 */
export const createOriginUSDArkModule = (moduleName: string) =>
  buildModule(moduleName, (m) => {
    const originUSD = m.getParameter('originUSD')
    const arkParams = m.getParameter('arkParams')

    const originUSDArk = m.contract('OriginUSDArk', [originUSD, arkParams], {
      id: 'OriginUSDArk',
    })

    return { originUSDArk }
  })

export default createOriginUSDArkModule('OriginUSDArk')

export type OriginUSDArkContracts = {
  originUSDArk: {
    address: string
  }
}
