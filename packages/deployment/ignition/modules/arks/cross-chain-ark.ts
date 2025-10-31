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
 * - CrossChainArk on the source chain
 *
 * Note: FleetProxy can be deployed before or after the CrossChainArk.
 * The relationship between CrossChainArk and FleetProxy is managed through
 * CrossChainRegistry.registerAdapterPeerPair() and must be registered separately
 * using the bridge/post-deployment/register-ark-fleet.ts script after deployment.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createCrossChainArkModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    // Common parameters
    const bridgeRouter = m.getParameter('bridgeRouter')
    const crossChainRegistry = m.getParameter('crossChainRegistry')
    const targetChainId = m.getParameter('targetChainId')
    const arkParams = m.getParameter('arkParams')

    // Deploy CrossChainArk with required constructor parameters
    const crossChainArk = m.contract('CrossChainArk', [
      crossChainRegistry, // _crossChainRegistry
      targetChainId, // _satelliteChainId
      arkParams, // _params
    ])

    return { crossChainArk }
  })
}
