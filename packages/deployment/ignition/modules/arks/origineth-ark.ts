import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create an OriginETHArkModule for deploying the OriginETHArk contract
 *
 * This function creates a module that deploys the OriginETHArk contract, which integrates with the Origin ETH protocol.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createOriginETHArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    const originETH = m.getParameter('originETH')
    const arm = m.getParameter('arm')
    const arkParams = m.getParameter('arkParams')

    const originETHArk = m.contract('OriginETHArk', [originETH, arm, arkParams])

    return { originETHArk }
  })
}

/**
 * Type definition for the returned contract address
 */
export type OriginETHArkContracts = {
  originETHArk: { address: string }
}
