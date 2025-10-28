// packages/deployment/ignition/modules/bridge.ts
import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('BridgeModule', (m) => {
  // Get the ProtocolAccessManager address from the config
  const protocolAccessManager = m.getParameter<Address>('protocolAccessManager')

  /**
   * @dev Deploy CrossChainRegistry first
   *
   * The CrossChainRegistry manages cross-chain relationships between
   * CrossChainArk and FleetProxy contracts. It requires:
   * - ProtocolAccessManager for access control
   * - Current chain ID is automatically set from block.chainid
   */
  const crossChainRegistry = m.contract('CrossChainRegistry', [protocolAccessManager])

  // Deploy BridgeRouter with CrossChainRegistry address
  const bridgeRouter = m.contract('BridgeRouter', [protocolAccessManager, crossChainRegistry])

  // Return the deployed contracts
  return {
    bridgeRouter,
    crossChainRegistry,
  }
})
