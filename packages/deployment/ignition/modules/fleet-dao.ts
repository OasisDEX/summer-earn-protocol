import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'
/**
 * Type definition for the returned contract addresses
 */
export type FleetContracts = {
  fleetCommander: { address: Address }
}

/**
 * Factory function to create a FleetDaoModule for deploying a FleetCommanderDao and its associated BufferArk
 *
 * This function creates a module that deploys the FleetCommanderDao contract and its associated BufferArk contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createFleetDaoModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    // Fleet module params exc. BufferArk
    const configurationManager = m.getParameter<string>('configurationManager')
    const protocolAccessManager = m.getParameter<string>('protocolAccessManager')
    const fleetName = m.getParameter<string>('fleetName')
    const fleetSymbol = m.getParameter<string>('fleetSymbol')
    const fleetDetails = m.getParameter<string>('fleetDetails')
    const asset = m.getParameter<string>('asset')
    const initialMinimumBufferBalance = m.getParameter<string>('initialMinimumBufferBalance')
    const initialRebalanceCooldown = m.getParameter<string>('initialRebalanceCooldown')
    const depositCap = m.getParameter<string>('depositCap')
    const initialTipRate = m.getParameter<string>('initialTipRate')
    const daoTipJar = m.getParameter<string>('daoTipJar')

    const fleetCommander = m.contract('FleetCommanderDao', [
      {
        name: fleetName,
        symbol: fleetSymbol,
        configurationManager: configurationManager,
        accessManager: protocolAccessManager,
        asset: asset,
        details: fleetDetails,
        initialMinimumBufferBalance: initialMinimumBufferBalance,
        initialRebalanceCooldown: initialRebalanceCooldown,
        depositCap: depositCap,
        initialTipRate: initialTipRate,
        tipJar: daoTipJar,
      },
    ])
    return { fleetCommander }
  })
}
