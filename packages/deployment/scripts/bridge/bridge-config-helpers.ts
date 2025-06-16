import { BridgeAdaptersConfig } from '../../types/bridge-types'

/**
 * Extracts bridge adapter configurations from the network config
 * @param config The network configuration object
 * @returns Bridge adapter configuration or undefined if not present
 */
export function getBridgeAdapterConfigs(config: any): BridgeAdaptersConfig | undefined {
  if (!config) {
    return undefined
  }

  // Extract adapter specific configurations
  const adapterConfigs: BridgeAdaptersConfig = {}

  console.log('config [debug]', config)

  // Check if bridge config is directly in config.bridge
  if (config.bridge?.adapters) {
    const adapters = config.bridge.adapters

    // LayerZero adapter config
    if (adapters.layerZero?.endpoint) {
      adapterConfigs.layerZero = {
        endpoint: adapters.layerZero.endpoint,
        supportedChains: adapters.layerZero.supportedChains || [],
        lzEids: adapters.layerZero.lzEids || [],
        readChannelId: adapters.layerZero.readChannelId,
        minGasLimits: adapters.layerZero.minGasLimits,
      }
    }

    // Stargate adapter config
    if (adapters.stargate?.router) {
      const chainMappings = (adapters.stargate.supportedChains || []).map((chain) => ({
        chainId: chain.chainId,
        stargateChainId: chain.stargateChainId,
      }))

      adapterConfigs.stargate = {
        router: adapters.stargate.router,
        chainMapping: chainMappings,
        supportedAssets: adapters.stargate.supportedAssets || {},
        // composeGasLimit: adapters.stargate.composeGasLimit, // TODO: Add to BridgeAdaptersConfig type
      }
    }
  }

  return Object.keys(adapterConfigs).length > 0 ? adapterConfigs : undefined
}

/**
 * Checks if bridge adapter configurations are present in the config
 * @param config The network configuration object
 * @returns True if any bridge adapter configuration is present
 */
export function hasBridgeAdapterConfigs(config: any): boolean {
  const adapterConfigs = getBridgeAdapterConfigs(config)
  return adapterConfigs !== undefined
}
