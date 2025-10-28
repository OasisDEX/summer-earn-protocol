import { BaseConfig } from '../../types/config-types'

/**
 * Extract adapter configuration from network config
 */
export function extractAdapterConfig(
  networkConfig: BaseConfig,
  adapterType: 'layerZero' | 'stargate',
): {
  address: string
  deployed: boolean
} | null {
  const adapter = networkConfig.deployedContracts?.bridge?.adapters?.[adapterType]

  if (!adapter) {
    return null
  }

  return {
    address: adapter.address,
    deployed: Boolean(
      adapter.address && adapter.address !== '0x0000000000000000000000000000000000000000',
    ),
  }
}

/**
 * Get all deployed adapters across all networks
 */
export function getAllDeployedAdapters(
  allNetworkConfigs: Record<string, BaseConfig>,
): Record<string, Record<string, { address: string; deployed: boolean }>> {
  const result: Record<string, Record<string, { address: string; deployed: boolean }>> = {}

  for (const [networkName, config] of Object.entries(allNetworkConfigs)) {
    result[networkName] = {}

    const layerZero = extractAdapterConfig(config, 'layerZero')
    if (layerZero) {
      result[networkName].layerZero = layerZero
    }

    const stargate = extractAdapterConfig(config, 'stargate')
    if (stargate) {
      result[networkName].stargate = stargate
    }
  }

  return result
}

/**
 * Check if a specific adapter is deployed on a network
 */
export function isAdapterDeployed(
  networkConfig: BaseConfig,
  adapterType: 'layerZero' | 'stargate',
): boolean {
  const adapter = extractAdapterConfig(networkConfig, adapterType)
  return adapter?.deployed ?? false
}

/**
 * Get adapter address for a specific network and adapter type
 */
export function getAdapterAddress(
  networkConfig: BaseConfig,
  adapterType: 'layerZero' | 'stargate',
): string | null {
  const adapter = extractAdapterConfig(networkConfig, adapterType)
  return adapter?.address ?? null
}

/**
 * Get all networks that have a specific adapter deployed
 */
export function getNetworksWithAdapter(
  allNetworkConfigs: Record<string, BaseConfig>,
  adapterType: 'layerZero' | 'stargate',
): string[] {
  return Object.entries(allNetworkConfigs)
    .filter(([, config]) => isAdapterDeployed(config, adapterType))
    .map(([networkName]) => networkName)
}

/**
 * Get cross-chain registry address from network config
 */
export function getCrossChainRegistryAddress(networkConfig: BaseConfig): string | null {
  return networkConfig.deployedContracts?.bridge?.crossChainRegistry?.address ?? null
}

/**
 * Check if cross-chain registry is deployed on a network
 */
export function isCrossChainRegistryDeployed(networkConfig: BaseConfig): boolean {
  const address = getCrossChainRegistryAddress(networkConfig)
  return Boolean(address && address !== '0x0000000000000000000000000000000000000000')
}

/**
 * Get bridge router address from network config
 */
export function getBridgeRouterAddress(networkConfig: BaseConfig): string | null {
  return networkConfig.deployedContracts?.bridge?.bridgeRouter?.address ?? null
}

/**
 * Check if bridge router is deployed on a network
 */
export function isBridgeRouterDeployed(networkConfig: BaseConfig): boolean {
  const address = getBridgeRouterAddress(networkConfig)
  return Boolean(address && address !== '0x0000000000000000000000000000000000000000')
}
