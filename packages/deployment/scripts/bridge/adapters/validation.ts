import { BaseConfig } from '../../../types/config-types'
import { AdapterConfigurationError } from './errors'

/**
 * Validate that required config fields exist for bridge operations
 */
export function validateBridgeConfig(config: BaseConfig): void {
  if (!config.deployedContracts.bridge?.crossChainRegistry?.address) {
    throw new AdapterConfigurationError('CrossChainRegistry address not found in config')
  }
  if (!config.deployedContracts.gov?.protocolAccessManager?.address) {
    throw new AdapterConfigurationError('ProtocolAccessManager address not found in config')
  }
  if (!config.common.layerZero?.lzEndpoint) {
    throw new AdapterConfigurationError('LayerZero endpoint not configured')
  }
}
