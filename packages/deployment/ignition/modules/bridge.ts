// packages/deployment/ignition/modules/bridge.ts
import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('BridgeModule', (m) => {
  // Get the deployer account
  const deployer = m.getAccount(0)

  // Get the ProtocolAccessManager address from the config
  const protocolAccessManager = m.getParameter<Address>('protocolAccessManager')

  // Get chain configuration
  const chainIds = m.getParameter<number[]>('chainIds')
  const routerAddresses = m.getParameter<Address[]>('routerAddresses')

  // Deploy BridgeQueue first since it's needed for BridgeRouter
  const bridgeQueue = m.contract('BridgeQueue', [
    protocolAccessManager,
    '0x0000000000000000000000000000000000000000', // BridgeRouter address will be set after deployment
    deployer, // Initial queue manager
  ])

  // Deploy BridgeRouter with BridgeQueue address
  const bridgeRouter = m.contract('BridgeRouter', [
    protocolAccessManager,
    bridgeQueue, // Pass BridgeQueue address directly
    chainIds,
    routerAddresses,
  ])

  // Update BridgeQueue with BridgeRouter address
  m.call(bridgeQueue, 'setBridgeRouter', [bridgeRouter])

  // Return the deployed contracts
  return {
    bridgeRouter,
    bridgeQueue,
  }
})
