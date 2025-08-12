// packages/deployment/ignition/modules/bridge.ts
import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('BridgeModule', (m) => {
  // Get the ProtocolAccessManager address from the config
  const protocolAccessManager = m.getParameter<Address>('protocolAccessManager')
  const currentChainId = m.getParameter('currentChainId')

  // Deploy CrossChainRegistry first
  const crossChainRegistry = m.contract('CrossChainRegistry', [
    protocolAccessManager,
    currentChainId,
  ])

  // Deploy BridgeRouter with registry
  const bridgeRouter = m.contract('BridgeRouter', [protocolAccessManager, crossChainRegistry])

  // Return the deployed contracts
  return {
    bridgeRouter,
    crossChainRegistry,
  }
})
