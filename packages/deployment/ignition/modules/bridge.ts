// packages/deployment/ignition/modules/bridge.ts
import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('BridgeModule', (m) => {
  // Get the ProtocolAccessManager address from the config
  const protocolAccessManager = m.getParameter<Address>('protocolAccessManager')
  const currentChainId = m.getParameter('currentChainId')

  // Deploy BridgeRouter first
  const bridgeRouter = m.contract('BridgeRouter', [
    protocolAccessManager,
    '0x0000000000000000000000000000000000000000', // BridgeQueue address will be set after deployment
  ])

  // Deploy BridgeQueue with BridgeRouter as initial queue manager
  const bridgeQueue = m.contract('BridgeQueue', [
    protocolAccessManager,
    bridgeRouter, // Pass BridgeRouter address directly
    bridgeRouter, // BridgeRouter will be the initial queue manager
  ])

  // Set the BridgeQueue address in BridgeRouter via governance
  m.call(bridgeRouter, 'setBridgeQueue', [bridgeQueue])

  /**
   * @dev Deploy CrossChainRegistry
   *
   * The CrossChainRegistry manages cross-chain relationships between
   * CrossChainArk and FleetProxy contracts. It requires:
   * - ProtocolAccessManager for access control
   * - Current chain ID for cross-chain identification
   */
  const crossChainRegistry = m.contract('CrossChainRegistry', [
    protocolAccessManager,
    currentChainId,
  ])

  // Return the deployed contracts
  return {
    bridgeRouter,
    bridgeQueue,
    crossChainRegistry,
  }
})
