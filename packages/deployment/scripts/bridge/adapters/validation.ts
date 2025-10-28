import { BaseConfig } from '../../../types/config-types'
import {
  getAccessManagerAddress,
  getCrossChainRegistryAddress,
  getLayerZeroEndpoint,
} from '../../lib/config/getters'
import { AdapterConfigurationError } from './errors'

/**
 * Validate that required config fields exist for bridge operations
 */
export function validateBridgeConfig(config: BaseConfig): void {
  try {
    getCrossChainRegistryAddress(config)
    getAccessManagerAddress(config)
    getLayerZeroEndpoint(config)
  } catch (error) {
    throw new AdapterConfigurationError(
      error instanceof Error ? error.message : 'Configuration validation failed',
    )
  }
}
