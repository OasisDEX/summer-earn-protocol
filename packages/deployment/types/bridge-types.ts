import { Address } from 'viem'

export interface BridgeRouterConfig {
  chainIds: number[]
  routerAddresses: Address[]
}

export interface BridgeConfig {
  router: BridgeRouterConfig
  bridgeOptions: {
    adapterParams: {
      gasLimit: number
      calldataSize: number
      msgValue: number
      options: string
    }
  }
}

export interface DeployedBridge {
  bridgeRouter: { address: Address }
  bridgeQueue: { address: Address }
}
