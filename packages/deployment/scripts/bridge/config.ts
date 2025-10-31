import fs from 'node:fs'
import path from 'node:path'
import { BridgeAdaptersConfig, DeployedBridge } from '../../types/bridge-types'

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
      }
    }

    // Stargate adapter config
    if (adapters.stargate?.router) {
      const chainMappings = (adapters.stargate.supportedChains || []).map(
        (chain: { chainId: number; stargateChainId: number }) => ({
          chainId: chain.chainId,
          stargateChainId: chain.stargateChainId,
        }),
      )

      adapterConfigs.stargate = {
        router: adapters.stargate.router,
        chainMapping: chainMappings,
        supportedAssets: adapters.stargate.supportedAssets || {},
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

export function getBridgeDeploymentDir() {
  return path.join(process.cwd(), 'deployments', 'bridge')
}

export function getBridgeDeploymentFileName(network: string) {
  return `bridge-${network}.json`
}

export function getBridgeDeploymentPath(network: string) {
  return path.join(getBridgeDeploymentDir(), getBridgeDeploymentFileName(network))
}

export async function saveBridgeDeploymentJson(deployedBridge: DeployedBridge, network: string) {
  const deploymentsDir = getBridgeDeploymentDir()

  // Create directory if it doesn't exist
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true })
  }

  const filePath = getBridgeDeploymentPath(network)
  fs.writeFileSync(filePath, JSON.stringify(deployedBridge, null, 2))

  console.log(`Bridge deployment configuration saved to: ${filePath}`)
}
