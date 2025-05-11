import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Type definition for the returned contract addresses
 */
export type CrossChainArkContracts = {
  crossChainArk: { address: string }
  fleetProxy: { address: string }
}

/**
 * Factory function to create a CrossChainArkModule for deploying both CrossChainArk and FleetProxy
 *
 * This function creates a module that deploys:
 * 1. FleetProxy on the satellite chain
 * 2. CrossChainArk on the source chain
 * 3. Updates FleetProxy with the CrossChainArk address
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
    const bridgeOptions = m.getParameter('bridgeOptions')
    const arkParams = m.getParameter('arkParams')

    // FleetProxy specific parameters
    const fleetContract = m.getParameter('fleetContract')
    const accessManager = m.getParameter('accessManager')

    // Deploy FleetProxy first with a placeholder for sourceChainArk
    const fleetProxy = m.contract('FleetProxy', [
      accessManager,
      bridgeRouter,
      fleetContract,
      bridgeOptions,
      '0x0000000000000000000000000000000000000000', // Placeholder for sourceChainArk
    ])

    // Deploy CrossChainArk with the FleetProxy address
    const crossChainArk = m.contract('CrossChainArk', [
      bridgeQueue,
      bridgeRouter,
      targetChainId,
      fleetProxy,
      bridgeOptions,
      arkParams,
    ])

    // Update FleetProxy with the CrossChainArk address
    m.call(fleetProxy, 'setSourceChainArk', [crossChainArk])

    return { crossChainArk, fleetProxy }
  })
}
