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
    // Get parameters - including the CrossChainRegistry
    const accessManager = m.getParameter('accessManager')
    const bridgeRouter = m.getParameter('bridgeRouter')
    const crossChainRegistry = m.getParameter('crossChainRegistry')
    const fleetContract = m.getParameter('fleetContract')
    const sourceChainId = m.getParameter('sourceChainId')

    // Deploy FleetProxy with required constructor parameters
    const fleetProxy = m.contract('FleetProxy', [
      accessManager, // _accessManager
      bridgeRouter, // _bridgeRouter
      crossChainRegistry, // _crossChainRegistry
      fleetContract, // _fleetAddress
      sourceChainId, // _sourceChainId (uint16)
    ])

    return { fleetProxy }
  })
}
