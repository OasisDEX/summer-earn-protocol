import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('StargateAdapterModule', (m) => {
  // Get the BridgeRouter address from parameters
  const bridgeRouter = m.getParameter<Address>('bridgeRouter', undefined)
  const owner = m.getParameter<Address>('owner', undefined)
  const lzEndpoint = m.getParameter<Address>('lzEndpoint', undefined)

  // Validate required parameters
  if (!bridgeRouter) throw new Error('bridgeRouter parameter is required')
  if (!owner) throw new Error('owner parameter is required')
  if (!lzEndpoint) throw new Error('lzEndpoint parameter is required')

  // Deploy StargateAdapter for V2 - with all 3 required parameters
  const stargateAdapter = m.contract('StargateAdapter', [bridgeRouter, owner, lzEndpoint])

  // Return the deployed contract
  return {
    stargateAdapter,
  }
})
