import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('LayerZeroAdapterModule', (m) => {
  // Get required parameters
  const endpoint = m.getParameter<Address>('endpoint', undefined)
  const crossChainRegistry = m.getParameter<Address>('crossChainRegistry', undefined)
  const accessManager = m.getParameter<Address>('accessManager', undefined)
  const supportedChains = m.getParameter<number[]>('supportedChains', [])
  const lzEids = m.getParameter<number[]>('lzEids', [])
  const initialOwner = m.getParameter<Address>('initialOwner', undefined)

  // Validate required parameters
  if (!endpoint) throw new Error('endpoint parameter is required')
  if (!crossChainRegistry) throw new Error('crossChainRegistry parameter is required')
  if (!accessManager) throw new Error('accessManager parameter is required')
  if (!initialOwner) throw new Error('initialOwner parameter is required')
  if ((supportedChains as unknown as number[]).length === 0)
    throw new Error('supportedChains parameter is required')
  if ((lzEids as unknown as number[]).length === 0) throw new Error('lzEids parameter is required')
  if ((supportedChains as unknown as number[]).length !== (lzEids as unknown as number[]).length)
    throw new Error('supportedChains and lzEids must have same length')

  // Deploy LayerZeroAdapter with all required parameters
  const layerZeroAdapter = m.contract('LayerZeroAdapter', [
    endpoint,
    crossChainRegistry,
    accessManager,
    supportedChains,
    lzEids,
    initialOwner,
  ])

  return {
    layerZeroAdapter,
  }
})
