import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('StargateAdapterModule', (m) => {
  // Get the BridgeRouter address from parameters
  const bridgeRouter = m.getParameter<Address>('bridgeRouter', undefined)

  // Get Stargate configuration parameters
  const stargateRouter = m.getParameter<Address>('stargateRouter', undefined)
  const owner = m.getParameter<Address>('owner', undefined)

  // Validate required parameters
  if (!bridgeRouter) throw new Error('bridgeRouter parameter is required')
  if (!stargateRouter) throw new Error('stargateRouter parameter is required')
  if (!owner) throw new Error('owner parameter is required')

  // Deploy StargateAdapter - simplified, no configuration in the module
  const stargateAdapter = m.contract('StargateAdapter', [stargateRouter, bridgeRouter, owner])

  // Return the deployed contract
  return {
    stargateAdapter,
  }
})
