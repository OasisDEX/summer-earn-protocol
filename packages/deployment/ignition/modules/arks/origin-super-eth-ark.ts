import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an OriginSuperOETHArkModule for deploying the OriginSuperOETHArk contract
 *
 * This function creates a module that deploys the OriginSuperOETHArk contract, which integrates with the Origin ETH protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createOriginSuperOETHArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const originETH = m.getParameter('originETH')
    const arkParams = m.getParameter('arkParams')

    const originETHArk = m.contract('OriginSuperOETHArk', [originETH, arkParams])

    return { originETHArk }
  })
}
