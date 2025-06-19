import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Type definition for the returned contract addresses
 */
export type FleetProxyContract = {
  fleetProxy: { address: string }
}

/**
 * Factory function to create a FleetProxyModule for deploying FleetProxy on satellite chains
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createFleetProxyModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    // Get parameters - only essential contracts
    const accessManager = m.getParameter('accessManager')
    const bridgeRouter = m.getParameter('bridgeRouter')
    const bridgeQueue = m.getParameter('bridgeQueue')
    const fleetContract = m.getParameter('fleetContract')

    // Deploy FleetProxy with only essential parameters
    const fleetProxy = m.contract('FleetProxy', [
      accessManager,
      bridgeRouter,
      bridgeQueue,
      fleetContract,
    ])

    return { fleetProxy }
  })
}
