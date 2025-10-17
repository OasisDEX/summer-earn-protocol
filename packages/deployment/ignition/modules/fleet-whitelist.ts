import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'
/**
 * Type definition for the returned contract addresses
 */
export type FleetWhitelistContracts = {
  fleetCommander: { address: Address }
}

/**
 * Factory function to create a FleetWhitelistModule for deploying a FleetCommanderWhitelist and its associated BufferArk
 *
 * This function creates a module that deploys the FleetCommanderWhitelist contract and its associated BufferArk contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createFleetWhitelistModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    // FleetWhitelist module params exc. BufferArk
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
    const fleetCommanderRewardsManagerFactory = m.getParameter<string>(
      'fleetCommanderRewardsManagerFactory',
    )

    const fleetCommanderWhitelist = m.contract('FleetCommanderWhitelist', [
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
        fleetCommanderRewardsManagerFactory: fleetCommanderRewardsManagerFactory,
      },
    ])
    return { fleetCommanderWhitelist }
  })
}
