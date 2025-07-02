import { Address } from 'viem'

// export interface AdapterParams {
//   gasLimit: number
//   calldataSize: number
//   msgValue: number
//   options: string
// }

// export interface BridgeOptions {
//   specifiedAdapter: Address
//   adapterParams: AdapterParams
// }

export interface BridgeAdaptersConfig {
  layerZero?: {
    endpoint: Address
    supportedChains: Array<{
      chainId: number
      lzEid: number
    }>
    readChannelId?: number
    minGasLimits?: Record<string, number>
    readLib1002?: Address
    sendUln302?: Address
    receiveUln302?: Address
    executor?: Address
    readDVNs?: Address[]
    confirmations?: number
  }
  stargate?: {
    router: Address
    chainMapping: Array<{
      chainId: number
      stargateChainId: number
    }>
    supportedAssets: Array<{
      chainId: number
      asset: Address
      poolId: number
    }>
  }
}

export interface DeployedBridge {
  bridgeRouter: { address: Address }
  bridgeQueue: { address: Address }
  crossChainRegistry: { address: Address }
  adapters?: {
    layerZero?: { address: Address }
    stargate?: { address: Address }
  }
}

export interface DeployedBridgeAdapters {
  layerZero?: { address: Address }
  stargate?: { address: Address }
}
