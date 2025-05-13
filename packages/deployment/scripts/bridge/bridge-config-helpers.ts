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

  // Check if bridge config is directly in config.bridge
  if (config.bridge) {
    // LayerZero adapter config
    if (config.bridge.layerZero?.endpoint) {
      adapterConfigs.layerZero = {
        endpoint: config.bridge.layerZero.endpoint,
        supportedChains: config.bridge.layerZero.supportedChains || [],
        lzEids: config.bridge.layerZero.lzEids || [],
        readChannelId: config.bridge.layerZero.readChannelId,
        minGasLimits: config.bridge.layerZero.minGasLimits,
      }
    }

    // Stargate adapter config
    if (config.bridge.stargate?.router) {
      adapterConfigs.stargate = {
        router: config.bridge.stargate.router,
        chainMapping: config.bridge.stargate.chainMapping || [],
        supportedAssets: config.bridge.stargate.supportedAssets || [],
      }
    }
  }

  // If we didn't find adapter configs in config.bridge, check deployedContracts
  if (Object.keys(adapterConfigs).length === 0 && config.deployedContracts?.bridge) {
    // For logging purposes
    console.log('Looking for bridge adapter configs in deployedContracts.bridge section')

    // In some networks, the adapters configurations are in the deployedContracts section
    const deployedBridge = config.deployedContracts.bridge

    // LayerZero adapter config
    if (deployedBridge.layerZero?.endpoint) {
      adapterConfigs.layerZero = {
        endpoint: deployedBridge.layerZero.endpoint,
        supportedChains: deployedBridge.layerZero.supportedChains || [],
        lzEids: deployedBridge.layerZero.lzEids || [],
        readChannelId: deployedBridge.layerZero.readChannelId,
        minGasLimits: deployedBridge.layerZero.minGasLimits,
      }
    }

    // Stargate adapter config
    if (deployedBridge.stargate?.router) {
      adapterConfigs.stargate = {
        router: deployedBridge.stargate.router,
        chainMapping: deployedBridge.stargate.chainMapping || [],
        supportedAssets: deployedBridge.stargate.supportedAssets || [],
      }
    }
  }

  // Last resort: Check if there are deployed adapters and use their addresses
  // Only applicable for reading deployed adapters, not for deployment
  if (Object.keys(adapterConfigs).length === 0 && config.deployedContracts?.bridge?.adapters) {
    console.log('Found deployed adapter addresses, but missing full configuration')
    const adapters = config.deployedContracts.bridge.adapters

    // Check for common.layerZero configuration to get the endpoint
    let lzEndpoint = null
    if (config.common?.layerZero?.lzEndpoint) {
      lzEndpoint = config.common.layerZero.lzEndpoint
      console.log(`Found LayerZero endpoint in common config: ${lzEndpoint}`)
    }

    // If we have a LayerZero adapter address and an endpoint
    if (
      adapters.layerZero?.address &&
      adapters.layerZero.address !== '0x0000000000000000000000000000000000000000'
    ) {
      if (lzEndpoint) {
        console.log(`Found deployed LayerZero adapter: ${adapters.layerZero.address}`)
        adapterConfigs.layerZero = {
          endpoint: lzEndpoint,
          supportedChains: [],
          lzEids: [],
        }
      } else {
        console.log('Found LayerZero adapter address but missing endpoint configuration')
      }
    }

    // For Stargate, we need at least a router address
    if (
      adapters.stargate?.address &&
      adapters.stargate.address !== '0x0000000000000000000000000000000000000000'
    ) {
      // Check for config.bridge.stargate.router even if we don't have full config
      let stargateRouter = null
      if (config.bridge?.stargate?.router) {
        stargateRouter = config.bridge.stargate.router
      }

      if (stargateRouter) {
        console.log(`Found deployed Stargate adapter: ${adapters.stargate.address}`)
        adapterConfigs.stargate = {
          router: stargateRouter,
          chainMapping: [],
          supportedAssets: [],
        }
      } else {
        console.log('Found Stargate adapter address but missing router configuration')
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
