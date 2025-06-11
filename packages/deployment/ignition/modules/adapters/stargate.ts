import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('StargateAdapterModule', (m) => {
  // Get the BridgeRouter address from parameters
  const bridgeRouter = m.getParameter<Address>('bridgeRouter', undefined)
  const owner = m.getParameter<Address>('owner', undefined)
  const lzEndpoint = m.getParameter<Address>('lzEndpoint', undefined)
  const accessManager = m.getParameter<Address>('accessManager', undefined)

  // Validate required parameters
  if (!bridgeRouter) throw new Error('bridgeRouter parameter is required')
  if (!owner) throw new Error('owner parameter is required')
  if (!lzEndpoint) throw new Error('lzEndpoint parameter is required')
  if (!accessManager) throw new Error('accessManager parameter is required')

  // Deploy StargateAdapter with all 4 required constructor parameters
  const stargateAdapter = m.contract('StargateAdapter', [
    bridgeRouter, // _bridgeRouter
    owner, // _deployer
    lzEndpoint, // _lzEndpoint
    accessManager, // _accessManager
  ])

  // Return the deployed contract
  return {
    stargateAdapter,
  }
})
