// packages/deployment/ignition/modules/bridge.ts
import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('BridgeModule', (m) => {
  // Get the ProtocolAccessManager address from the config
  const protocolAccessManager = m.getParameter<Address>('protocolAccessManager')
  const currentChainId = m.getParameter('currentChainId')

  /**
   * @dev Deploy CrossChainRegistry first
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

  // Deploy BridgeRouter with CrossChainRegistry address
  const bridgeRouter = m.contract('BridgeRouter', [protocolAccessManager, crossChainRegistry])

  // Return the deployed contracts
  return {
    bridgeRouter,
    crossChainRegistry,
  }
})
