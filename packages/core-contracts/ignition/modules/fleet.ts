import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * Factory function to create a FleetModule for deploying a FleetCommander and its associated BufferArk
 *
 * This function creates a module that deploys the FleetCommander contract and its associated BufferArk contract.
 *
 * @param {string} moduleName - Name of the module
 * @returns {Function} A function that builds the module
 */
export function createFleetModule(moduleName: string) {
  return buildModule(moduleName, (m) => {
    // Fleet module params exc. BufferArk
    const configurationManager = m.getParameter<string>('configurationManager')
    const protocolAccessManager = m.getParameter<string>('protocolAccessManager')
    const fleetName = m.getParameter<string>('fleetName')
    const fleetSymbol = m.getParameter<string>('fleetSymbol')
    const asset = m.getParameter<string>('asset')
    const initialArks = m.getParameter<string[]>('initialArks')
    const initialMinimumBufferBalance = m.getParameter<string>('initialMinimumBufferBalance')
    const initialRebalanceCooldown = m.getParameter<string>('initialRebalanceCooldown')
    const depositCap = m.getParameter<string>('depositCap')
    const initialTipRate = m.getParameter<string>('initialTipRate')

    // Deploy BufferArk
    const bufferArkParams = m.getParameter<any>('bufferArkParams')
    const bufferArk = m.contract('BufferArk', [bufferArkParams])

    const fleetCommander = m.contract('FleetCommander', [
      {
        name: fleetName,
        symbol: fleetSymbol,
        initialArks: initialArks,
        configurationManager: configurationManager,
        accessManager: protocolAccessManager,
        asset: asset,
        bufferArk: bufferArk,
        initialMinimumBufferBalance: initialMinimumBufferBalance,
        initialRebalanceCooldown: initialRebalanceCooldown,
        depositCap: depositCap,
        initialTipRate: initialTipRate,
      },
    ])

    return { fleetCommander, bufferArk }
  })
}

/**
 * Type definition for the returned contract addresses
 */
export type FleetContracts = {
  fleetCommander: { address: string }
  bufferArk: { address: string }
}
