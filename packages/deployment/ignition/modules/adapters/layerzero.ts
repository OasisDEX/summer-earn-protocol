import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { Address } from 'viem'

export default buildModule('LayerZeroAdapterModule', (m) => {
  // Get the BridgeRouter address from parameters
  const bridgeRouter = m.getParameter<Address>('bridgeRouter', undefined)

  // Get LayerZero configuration parameters
  const lzEndpoint = m.getParameter<Address>('lzEndpoint', undefined)
  const chainIds = m.getParameter<number[]>('chainIds', [])
  const lzEids = m.getParameter<number[]>('lzEids', [])
  const owner = m.getParameter<Address>('owner', undefined)
  const accessManager = m.getParameter<Address>('accessManager', undefined)

  // Validate required parameters
  if (!bridgeRouter) throw new Error('bridgeRouter parameter is required')
  if (!lzEndpoint) throw new Error('lzEndpoint parameter is required')
  if (!owner) throw new Error('owner parameter is required')
  if (!accessManager) throw new Error('accessManager parameter is required')

  // Deploy LayerZeroAdapter with all 6 required constructor parameters
  const layerZeroAdapter = m.contract('LayerZeroAdapter', [
    lzEndpoint, // _endpoint
    bridgeRouter, // _bridgeRouter
    chainIds, // _supportedChains
    lzEids, // _lzEids
    owner, // _deployer
    accessManager, // _accessManager
  ])

  // Return the deployed contract
  return {
    layerZeroAdapter,
  }
})
