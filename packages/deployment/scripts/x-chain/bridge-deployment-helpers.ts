import kleur from 'kleur'
import { getAddress } from 'viem'
import { BaseConfig } from '../../types/config-types'
import {
  extractAdapterConfig,
  getBridgeRouterAddressOptional as getBridgeRouterAddress,
  getCrossChainRegistryAddressOptional as getCrossChainRegistryAddress,
  isAdapterDeployed,
  hasBridgeRouter as isBridgeRouterDeployed,
  hasCrossChainRegistry as isCrossChainRegistryDeployed,
} from '../lib/config/getters'
import { getConfigByNetwork } from '../lib/config/handler'
import {
  BridgeValidationOptions,
  BridgeValidationResult,
  validateBridgeComponents,
} from './adapters/validation'

/**
 * Validate that required bridge infrastructure is deployed
 * Uses consolidated validation logic from adapters/validation.ts
 */
export function validateBridgeInfrastructure(
  networkConfig: BaseConfig,
  requiredComponents: BridgeValidationOptions = {},
): BridgeValidationResult {
  return validateBridgeComponents(networkConfig, requiredComponents)
}

/**
 * Get deployment status for all bridge components
 */
export function getBridgeDeploymentStatus(networkConfig: BaseConfig): {
  crossChainRegistry: boolean
  bridgeRouter: boolean
  layerZero: boolean
  stargate: boolean
} {
  return {
    crossChainRegistry: isCrossChainRegistryDeployed(networkConfig),
    bridgeRouter: isBridgeRouterDeployed(networkConfig),
    layerZero: isAdapterDeployed(networkConfig, 'layerZero'),
    stargate: isAdapterDeployed(networkConfig, 'stargate'),
  }
}

/**
 * Log bridge deployment status
 */
export function logBridgeDeploymentStatus(networkConfig: BaseConfig, networkName: string): void {
  const status = getBridgeDeploymentStatus(networkConfig)

  console.log(kleur.blue(`\nBridge Deployment Status for ${networkName}:`))
  console.log(
    `  CrossChainRegistry: ${status.crossChainRegistry ? kleur.green('✓') : kleur.red('✗')}`,
  )
  console.log(`  BridgeRouter: ${status.bridgeRouter ? kleur.green('✓') : kleur.red('✗')}`)
  console.log(`  LayerZeroAdapter: ${status.layerZero ? kleur.green('✓') : kleur.red('✗')}`)
  console.log(`  StargateAdapter: ${status.stargate ? kleur.green('✓') : kleur.red('✗')}`)
}

/**
 * Get contract addresses for bridge components
 */
export function getBridgeAddresses(networkConfig: BaseConfig): {
  crossChainRegistry?: string
  bridgeRouter?: string
  layerZero?: string
  stargate?: string
} {
  const addresses: Record<string, string | undefined> = {}

  const crossChainRegistry = getCrossChainRegistryAddress(networkConfig)
  if (crossChainRegistry) addresses.crossChainRegistry = crossChainRegistry

  const bridgeRouter = getBridgeRouterAddress(networkConfig)
  if (bridgeRouter) addresses.bridgeRouter = bridgeRouter

  const layerZero = extractAdapterConfig(networkConfig, 'layerZero')
  if (layerZero?.deployed) addresses.layerZero = layerZero.address

  const stargate = extractAdapterConfig(networkConfig, 'stargate')
  if (stargate?.deployed) addresses.stargate = stargate.address

  return addresses
}

/**
 * Validate contract addresses are properly formatted
 */
export function validateContractAddresses(addresses: Record<string, string | undefined>): {
  valid: boolean
  invalid: string[]
} {
  const invalid: string[] = []

  for (const [component, address] of Object.entries(addresses)) {
    if (address) {
      try {
        getAddress(address as `0x${string}`)
      } catch {
        invalid.push(component)
      }
    }
  }

  return {
    valid: invalid.length === 0,
    invalid,
  }
}

/**
 * Get network configuration for bridge deployment
 */
export async function getBridgeNetworkConfig(
  networkName: string,
  useBummerConfig: boolean = false,
): Promise<BaseConfig> {
  return getConfigByNetwork(
    networkName,
    { common: true, gov: true, bridge: true },
    useBummerConfig,
  ) as BaseConfig
}

/**
 * Get all network configurations for cross-chain operations
 */
export async function getAllBridgeNetworkConfigs(
  useBummerConfig: boolean = false,
): Promise<Record<string, BaseConfig>> {
  return getConfigByNetwork('all', { common: true }, useBummerConfig) as Record<string, BaseConfig>
}

/**
 * Check if a network supports cross-chain operations
 */
export function supportsCrossChain(networkConfig: BaseConfig): boolean {
  const status = getBridgeDeploymentStatus(networkConfig)
  return status.crossChainRegistry && status.bridgeRouter && (status.layerZero || status.stargate)
}

/**
 * Get supported cross-chain networks
 */
export function getCrossChainNetworks(allNetworkConfigs: Record<string, BaseConfig>): string[] {
  return Object.entries(allNetworkConfigs)
    .filter(([, config]) => supportsCrossChain(config))
    .map(([networkName]) => networkName)
}

/**
 * Log cross-chain network support
 */
export function logCrossChainSupport(allNetworkConfigs: Record<string, BaseConfig>): void {
  const supportedNetworks = getCrossChainNetworks(allNetworkConfigs)

  console.log(kleur.blue('\nCross-Chain Support:'))
  if (supportedNetworks.length === 0) {
    console.log(kleur.yellow('  No networks support cross-chain operations'))
  } else {
    console.log(kleur.green(`  Supported networks: ${supportedNetworks.join(', ')}`))
  }
}
