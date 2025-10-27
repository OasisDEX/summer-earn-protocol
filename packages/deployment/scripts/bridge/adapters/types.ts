import { BaseConfig, NetworkConfigMap } from '../../../types/config-types'

export interface ChainInfo {
  chainId: number
  endpointId: number
}

// Re-export for convenience
export type { BaseConfig, NetworkConfigMap }
