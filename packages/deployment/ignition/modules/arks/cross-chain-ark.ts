import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Type definition for the returned contract addresses
 */
export type CrossChainArkContracts = {
  crossChainArk: { address: string }
  // fleetProxy property removed as it's now deployed separately
}

/**
 * Factory function to create a CrossChainArkModule for deploying CrossChainArk on the source chain
 *
 * This function creates a module that deploys:
 * - CrossChainArk on the source chain with targetProxy initially set to address(0)
 *
 * Note: FleetProxy can be deployed before or after the CrossChainArk.
 * The targetProxy can be configured later using the setTargetProxy() function.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createCrossChainArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    // Common parameters
    const bridgeQueue = m.getParameter('bridgeQueue')
    const bridgeRouter = m.getParameter('bridgeRouter')
    const targetChainId = m.getParameter('targetChainId')
    const arkParams = m.getParameter('arkParams')

    // Deploy CrossChainArk without targetProxy parameter
    const crossChainArk = m.contract('CrossChainArk', [
      bridgeQueue,
      bridgeRouter,
      targetChainId,
      arkParams,
    ])

    return { crossChainArk }
  })
}
