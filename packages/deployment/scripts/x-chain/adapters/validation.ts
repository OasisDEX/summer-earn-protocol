import { BaseConfig } from '../../../types/config-types'
import {
  getAccessManagerAddress,
  getCrossChainRegistryAddress,
  getLayerZeroEndpoint,
  hasBridgeRouter,
  hasCrossChainRegistry,
  isAdapterDeployed,
} from '../../lib/config/getters'
import { AdapterConfigurationError } from './errors'

/**
 * Bridge component validation result
 */
export interface BridgeValidationResult {
  valid: boolean
  missing: string[]
}

/**
 * Options for bridge infrastructure validation
 */
export interface BridgeValidationOptions {
  crossChainRegistry?: boolean
  bridgeRouter?: boolean
  layerZero?: boolean
  stargate?: boolean
}

/**
 * Shared validation helper that checks bridge components with flexible error handling
 * @param config The network configuration
 * @param requiredComponents Components to validate
 * @returns Validation result with missing components
 */
export function validateBridgeComponents(
  config: BaseConfig,
  requiredComponents: BridgeValidationOptions = {},
): BridgeValidationResult {
  const missing: string[] = []

  if (requiredComponents.crossChainRegistry && !hasCrossChainRegistry(config)) {
    missing.push('CrossChainRegistry')
  }

  if (requiredComponents.bridgeRouter && !hasBridgeRouter(config)) {
    missing.push('BridgeRouter')
  }

  if (requiredComponents.layerZero && !isAdapterDeployed(config, 'layerZero')) {
    missing.push('LayerZeroAdapter')
  }

  if (requiredComponents.stargate && !isAdapterDeployed(config, 'stargate')) {
    missing.push('StargateAdapter')
  }

  return {
    valid: missing.length === 0,
    missing,
  }
}

/**
 * Validate that required config fields exist for bridge operations
 * This function is used specifically for adapter operations and throws errors
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
