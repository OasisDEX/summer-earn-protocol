import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('StargateAdapterModule', (m) => {
  // Get the BridgeRouter address from parameters
  const bridgeRouter = m.getParameter<Address>('bridgeRouter', undefined)
  const owner = m.getParameter<Address>('owner', undefined)

  // Validate required parameters
  if (!bridgeRouter) throw new Error('bridgeRouter parameter is required')
  if (!owner) throw new Error('owner parameter is required')

  // Deploy StargateAdapter for V2 - simplified constructor
  const stargateAdapter = m.contract('StargateAdapter', [bridgeRouter, owner])

  // Return the deployed contract
  return {
    stargateAdapter,
  }
})
