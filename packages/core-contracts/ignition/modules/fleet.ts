import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

/**
 * FleetModule for deploying a FleetCommander and its associated BufferArk
 *
 * This module deploys the FleetCommander contract and its associated BufferArk contract.
 *
 * @param {string} configurationManager - Address of the ConfigurationManager contract
 * @param {string} protocolAccessManager - Address of the ProtocolAccessManager contract
 * @param {string} fleetName - Name of the fleet
 * @param {string} fleetSymbol - Symbol for the fleet's token
 * @param {string} asset - Address of the asset token managed by the fleet
 * @param {string[]} initialArks - Array of initial Ark addresses
 * @param {string} initialMinimumFundsBufferBalance - Initial minimum balance for the funds buffer
 * @param {string} initialRebalanceCooldown - Initial cooldown period for rebalancing
 * @param {string} depositCap - Maximum allowed deposit
 * @param {string} initialTipRate - Initial rate for tips
 * @param {object} bufferArkParams - Parameters for the BufferArk contract
 *
 * @returns {FleetContracts} An object containing the addresses of the deployed FleetCommander and BufferArk contracts
 */
export default buildModule('FleetModule', (m) => {
  // Fleet module params exc. BufferArk
  const configurationManager = m.getParameter<string>('configurationManager')
  const protocolAccessManager = m.getParameter<string>('protocolAccessManager')
  const fleetName = m.getParameter<string>('fleetName')
  const fleetSymbol = m.getParameter<string>('fleetSymbol')
  const asset = m.getParameter<string>('asset')
  const initialArks = m.getParameter<string[]>('initialArks')
  const initialMinimumFundsBufferBalance = m.getParameter<string>(
    'initialMinimumFundsBufferBalance',
  )
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
      initialMinimumFundsBufferBalance: initialMinimumFundsBufferBalance,
      initialRebalanceCooldown: initialRebalanceCooldown,
      depositCap: depositCap,
      initialTipRate: initialTipRate,
    },
  ])

  return { fleetCommander, bufferArk }
})

/**
 * Type definition for the returned contract addresses
 */
export type FleetContracts = {
  fleetCommander: { address: string }
  bufferArk: { address: string }
}
