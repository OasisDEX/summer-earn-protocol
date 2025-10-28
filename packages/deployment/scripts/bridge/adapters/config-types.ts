/**
 * Type definitions for adapter configuration JSON files
 */

// For layerzero.json structure
export interface LayerZeroChainConfig {
  minGasLimits?: {
    stateRead: number
    generalMessage: number
  }
}

export interface LayerZeroConfig {
  chainConfig: {
    [chainId: string]: LayerZeroChainConfig
  }
}

// For stargate.json structure
export interface StargateContractsConfig {
  [chainId: string]: {
    [assetSymbol: string]: string
  }
}

export interface StargateConfig {
  contracts: StargateContractsConfig
}
