import { Address } from 'viem'
import { BaseConfig } from '../../../types/config-types'
import { BridgeAdaptersConfig } from '../../../types/bridge-types'
import { ADDRESS_ZERO } from '../infrastructure/constants'

/**
 * Generic helper to get nested property from object using dot notation
 */
function getNestedProperty(obj: any, path: string): any {
  return path.split('.').reduce((current, key) => current?.[key], obj)
}

/**
 * Generic helper to check if an address is valid (not null, undefined, or zero address)
 */
function isValidAddress(address: any): boolean {
  return !!(address && address !== ADDRESS_ZERO)
}

/**
 * Generic getter for required addresses with descriptive error messages
 * @param config The configuration object
 * @param path Dot notation path to the address (e.g., 'bridge.bridgeRouter.address')
 * @param contractName Human-readable contract name for error messages
 * @param prerequisite What needs to be deployed first (for error messages)
 */
export function getRequiredAddress(
  config: BaseConfig,
  path: string,
  contractName: string,
  prerequisite: string,
): Address {
  const address = getNestedProperty(config, path)
  
  if (!isValidAddress(address)) {
    throw new Error(
      `${contractName} address not found in configuration. Make sure ${prerequisite} is deployed.`
    )
  }
  
  return address as Address
}

/**
 * Generic getter for optional addresses (returns undefined if not found)
 * @param config The configuration object
 * @param path Dot notation path to the address
 */
export function getOptionalAddress(config: BaseConfig, path: string): Address | undefined {
  const address = getNestedProperty(config, path)
  return isValidAddress(address) ? (address as Address) : undefined
}

// ============================================================================
// BRIDGE CONFIG GETTERS
// ============================================================================

/**
 * Get the BridgeRouter address from configuration
 */
export function getBridgeRouterAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.bridge.bridgeRouter.address',
    'BridgeRouter',
    'bridge contracts'
  )
}

/**
 * Get the BridgeQueue address from configuration
 */
export function getBridgeQueueAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.bridge.bridgeQueue.address',
    'BridgeQueue',
    'bridge contracts'
  )
}

/**
 * Get the CrossChainRegistry address from configuration
 */
export function getCrossChainRegistryAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.bridge.crossChainRegistry.address',
    'CrossChainRegistry',
    'bridge contracts'
  )
}

/**
 * Get the LayerZero adapter address from configuration
 */
export function getLayerZeroAdapterAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.bridge.adapters.layerZero.address',
    'LayerZero adapter',
    'bridge adapters'
  )
}

/**
 * Get the Stargate adapter address from configuration
 */
export function getStargateAdapterAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.bridge.adapters.stargate.address',
    'Stargate adapter',
    'bridge adapters'
  )
}

/**
 * Check if bridge configuration exists
 */
export function hasBridgeConfig(config: BaseConfig): boolean {
  return !!(config.deployedContracts.bridge)
}

/**
 * Check if LayerZero adapter is configured
 */
export function hasLayerZeroAdapter(config: BaseConfig): boolean {
  return isValidAddress(config.deployedContracts.bridge?.adapters?.layerZero?.address)
}

/**
 * Check if Stargate adapter is configured
 */
export function hasStargateAdapter(config: BaseConfig): boolean {
  return isValidAddress(config.deployedContracts.bridge?.adapters?.stargate?.address)
}

/**
 * Get the BridgeRouter address from configuration (optional)
 * Returns undefined if not found
 */
export function getBridgeRouterAddressOptional(config: BaseConfig): Address | undefined {
  return getOptionalAddress(config, 'deployedContracts.bridge.bridgeRouter.address')
}

/**
 * Get the CrossChainRegistry address from configuration (optional)
 * Returns undefined if not found
 */
export function getCrossChainRegistryAddressOptional(config: BaseConfig): Address | undefined {
  return getOptionalAddress(config, 'deployedContracts.bridge.crossChainRegistry.address')
}

/**
 * Get the LayerZero adapter address from configuration (optional)
 * Returns undefined if not found
 */
export function getLayerZeroAdapterAddressOptional(config: BaseConfig): Address | undefined {
  return getOptionalAddress(config, 'deployedContracts.bridge.adapters.layerZero.address')
}

/**
 * Get the Stargate adapter address from configuration (optional)
 * Returns undefined if not found
 */
export function getStargateAdapterAddressOptional(config: BaseConfig): Address | undefined {
  return getOptionalAddress(config, 'deployedContracts.bridge.adapters.stargate.address')
}

/**
 * Get adapter address for a specific adapter type (optional)
 * Returns undefined if not found
 */
export function getAdapterAddress(
  config: BaseConfig,
  adapterType: 'layerZero' | 'stargate',
): Address | undefined {
  return getOptionalAddress(config, `deployedContracts.bridge.adapters.${adapterType}.address`)
}

/**
 * Check if BridgeRouter is deployed
 */
export function hasBridgeRouter(config: BaseConfig): boolean {
  return isValidAddress(config.deployedContracts.bridge?.bridgeRouter?.address)
}

/**
 * Check if CrossChainRegistry is deployed
 */
export function hasCrossChainRegistry(config: BaseConfig): boolean {
  return isValidAddress(config.deployedContracts.bridge?.crossChainRegistry?.address)
}

/**
 * Check if a specific adapter is deployed on a network
 */
export function isAdapterDeployed(
  config: BaseConfig,
  adapterType: 'layerZero' | 'stargate',
): boolean {
  return isValidAddress(config.deployedContracts.bridge?.adapters?.[adapterType]?.address)
}

/**
 * Interface for existing adapter addresses
 */
export interface ExistingAdapterAddresses {
  layerZero?: Address
  stargate?: Address
}

/**
 * Get all existing adapter addresses from configuration
 * Returns both LayerZero and Stargate adapter addresses if they exist
 */
export function getExistingAdapterAddresses(config: BaseConfig): ExistingAdapterAddresses {
  return {
    layerZero: getLayerZeroAdapterAddressOptional(config),
    stargate: getStargateAdapterAddressOptional(config),
  }
}

// ============================================================================
// MULTI-NETWORK BRIDGE HELPERS
// ============================================================================

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
    deployed: Boolean(adapter.address && adapter.address !== ADDRESS_ZERO),
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

// ============================================================================
// BRIDGE ADAPTER CONFIG GETTERS
// ============================================================================

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
  if (config.bridge?.adapters) {
    const adapters = config.bridge.adapters

    // LayerZero adapter config
    if (adapters.layerZero?.endpoint) {
      adapterConfigs.layerZero = {
        endpoint: adapters.layerZero.endpoint,
        supportedChains: adapters.layerZero.supportedChains || [],
        lzEids: adapters.layerZero.lzEids || [],
        // minGasLimits is not in the BridgeAdaptersConfig type yet, so we omit it
        // minGasLimits: adapters.layerZero.minGasLimits,
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
        supportedAssets: adapters.stargate.supportedAssets || [],
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

// ============================================================================
// GOVERNANCE CONFIG GETTERS
// ============================================================================

/**
 * Get the ProtocolAccessManager address from configuration
 */
export function getAccessManagerAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.gov.protocolAccessManager.address',
    'ProtocolAccessManager',
    'governance contracts'
  )
}

/**
 * Get the TimelockController address from configuration
 */
export function getTimelockAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.gov.timelock.address',
    'TimelockController',
    'governance contracts'
  )
}

/**
 * Get the SUMMER token address from configuration
 */
export function getSummerTokenAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.gov.summerToken.address',
    'SUMMER token',
    'governance contracts'
  )
}

/**
 * Get the SummerGovernor address from configuration
 */
export function getSummerGovernorAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.gov.summerGovernor.address',
    'SummerGovernor',
    'governance contracts'
  )
}

/**
 * Get the RewardsRedeemer address from configuration
 */
export function getRewardsRedeemerAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.gov.rewardsRedeemer.address',
    'RewardsRedeemer',
    'governance contracts'
  )
}

// ============================================================================
// CORE CONFIG GETTERS
// ============================================================================

/**
 * Get the HarborCommand address from configuration
 */
export function getHarborCommandAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.core.harborCommand.address',
    'HarborCommand',
    'core contracts'
  )
}

/**
 * Get the ConfigurationManager address from configuration
 */
export function getConfigurationManagerAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.core.configurationManager.address',
    'ConfigurationManager',
    'core contracts'
  )
}

/**
 * Get the TipJar address from configuration
 */
export function getTipJarAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.core.tipJar.address',
    'TipJar',
    'core contracts'
  )
}

/**
 * Get the Raft address from configuration
 */
export function getRaftAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.core.raft.address',
    'Raft',
    'core contracts'
  )
}

/**
 * Get the AdmiralsQuarters address from configuration
 */
export function getAdmiralsQuartersAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.core.admiralsQuarters.address',
    'AdmiralsQuarters',
    'core contracts'
  )
}

/**
 * Get the FleetCommanderRewardsManagerFactory address from configuration
 */
export function getFleetCommanderRewardsManagerFactoryAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.core.fleetCommanderRewardsManagerFactory.address',
    'FleetCommanderRewardsManagerFactory',
    'core contracts'
  )
}

/**
 * Get the InstitutionalVaultRegistry address from configuration (optional)
 */
export function getInstitutionalVaultRegistryAddress(config: BaseConfig): Address | undefined {
  return getOptionalAddress(config, 'deployedContracts.core.institutionalVaultRegistry.address')
}

// ============================================================================
// COMMON CONFIG GETTERS
// ============================================================================

/**
 * Get the swap provider address from configuration
 */
export function getSwapProviderAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'common.swapProvider',
    'SwapProvider',
    'common configuration'
  )
}

/**
 * Get the LayerZero endpoint address from configuration
 */
export function getLayerZeroEndpoint(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'common.layerZero.lzEndpoint',
    'LayerZero endpoint',
    'common configuration'
  )
}

/**
 * Get the chain ID from configuration
 */
export function getChainIdFromConfig(config: BaseConfig): number {
  const chainId = config.common.chainId
  if (!chainId) {
    throw new Error('Chain ID is not configured')
  }
  
  const parsedChainId = Number(chainId)
  if (isNaN(parsedChainId) || parsedChainId <= 0) {
    throw new Error(`Invalid chain ID: ${chainId}`)
  }
  
  return parsedChainId
}

/**
 * Get the LayerZero eID from configuration
 */
export function getLayerZeroEid(config: BaseConfig): string {
  const eid = config.common.layerZero.eID
  if (!eid) {
    throw new Error('LayerZero eID is not configured')
  }
  return eid
}

/**
 * Get the tip rate from configuration
 */
export function getTipRate(config: BaseConfig): string {
  const tipRate = config.common.tipRate
  if (!tipRate) {
    throw new Error('Tip rate is not configured')
  }
  return tipRate
}

// ============================================================================
// BUY AND BURN CONFIG GETTERS
// ============================================================================

/**
 * Get the BuyAndBurn address from configuration
 */
export function getBuyAndBurnAddress(config: BaseConfig): Address {
  return getRequiredAddress(
    config,
    'deployedContracts.buyAndBurn.buyAndBurn.address',
    'BuyAndBurn',
    'buy and burn contracts'
  )
}

// ============================================================================
// TOKEN CONFIG GETTERS
// ============================================================================

/**
 * Get a token address from configuration
 */
export function getTokenAddress(config: BaseConfig, token: string): Address {
  return getRequiredAddress(
    config,
    `tokens.${token}`,
    `${token.toUpperCase()} token`,
    'token configuration'
  )
}

/**
 * Get WETH address from configuration
 */
export function getWethAddress(config: BaseConfig): Address {
  return getTokenAddress(config, 'weth')
}

/**
 * Get USDC address from configuration
 */
export function getUsdcAddress(config: BaseConfig): Address {
  return getTokenAddress(config, 'usdc')
}

/**
 * Get DAI address from configuration
 */
export function getDaiAddress(config: BaseConfig): Address {
  return getTokenAddress(config, 'dai')
}

/**
 * Get USDT address from configuration
 */
export function getUsdtAddress(config: BaseConfig): Address {
  return getTokenAddress(config, 'usdt')
}
