import { Address } from 'viem'
import { BaseConfig } from '../../types/config-types'
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
  return !!(address && address !== ADDRESS_ZERO && address !== '0x0000000000000000000000000000000000000000')
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
