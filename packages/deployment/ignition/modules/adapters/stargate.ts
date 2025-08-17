import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('StargateAdapterModule', (m) => {
  // Get the required parameters
  const crossChainRegistry = m.getParameter<Address>('crossChainRegistry', undefined)
  const accessManager = m.getParameter<Address>('accessManager', undefined)
  const lzEndpoint = m.getParameter<Address>('lzEndpoint', undefined)
  const harborCommand = m.getParameter<Address>('harborCommand', undefined)

  // Validate required parameters
  if (!crossChainRegistry) throw new Error('crossChainRegistry parameter is required')
  if (!accessManager) throw new Error('accessManager parameter is required')
  if (!lzEndpoint) throw new Error('lzEndpoint parameter is required')
  if (!harborCommand) throw new Error('harborCommand parameter is required')

  // Deploy StargateAdapter with all required parameters
  const stargateAdapter = m.contract('StargateAdapter', [
    crossChainRegistry,
    accessManager,
    lzEndpoint,
    harborCommand,
  ])

  return {
    stargateAdapter,
  }
})
