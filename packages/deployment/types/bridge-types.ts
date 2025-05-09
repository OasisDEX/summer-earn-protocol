import { Address } from 'viem'

export type BridgeConfig = {
  bridgeRouter: {
    chainIds: number[]
    routerAddresses: Address[]
  }
  bridgeOptions: {
    adapterParams: {
      gasLimit: number
      calldataSize: number
      msgValue: number
      options: string
    }
  }
}

export type DeployedBridge = {
  bridgeRouter: {
    address: Address
  }
  bridgeQueue: {
    address: Address
  }
}
