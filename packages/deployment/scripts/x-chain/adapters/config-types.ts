/**
 * Type definitions for adapter configuration JSON files
 */

// For layerzero.json structure
export interface LayerZeroChainConfig {
  // Future configuration properties can be added here
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
