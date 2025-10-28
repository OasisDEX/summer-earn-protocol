import { Address } from 'viem'
import { CrossChainConfig } from './cross-chain'

/**
 * Get FleetProxy address for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns FleetProxy address
 * @throws Error if not found
 */
export function getFleetProxyAddress(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): Address {
  const destination = config.destinations.find((d) => d.chainId === chainId)
  if (!destination) {
    throw new Error(`No destination found for chain ${chainId} in cross-chain config`)
  }

  const protocolConfig = destination.protocols.find((p) => p.protocol === protocol)
  if (!protocolConfig?.fleetProxyAddress) {
    throw new Error(`FleetProxy address not found for chain ${chainId} protocol ${protocol}`)
  }

  return protocolConfig.fleetProxyAddress as Address
}

/**
 * Get CrossChainArk address for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns CrossChainArk address
 * @throws Error if not found
 */
export function getCrossChainArkAddress(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): Address {
  const destination = config.destinations.find((d) => d.chainId === chainId)
  if (!destination) {
    throw new Error(`No destination found for chain ${chainId} in cross-chain config`)
  }

  const protocolConfig = destination.protocols.find((p) => p.protocol === protocol)
  if (!protocolConfig?.crossChainArkAddress) {
    throw new Error(`CrossChainArk address not found for chain ${chainId} protocol ${protocol}`)
  }

  return protocolConfig.crossChainArkAddress as Address
}

/**
 * Get satellite fleet address for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns Satellite fleet address
 * @throws Error if not found
 */
export function getSatelliteFleetAddress(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): Address {
  const destination = config.destinations.find((d) => d.chainId === chainId)
  if (!destination) {
    throw new Error(`No destination found for chain ${chainId} in cross-chain config`)
  }

  const protocolConfig = destination.protocols.find((p) => p.protocol === protocol)
  if (!protocolConfig?.satelliteFleetAddress) {
    throw new Error(`Satellite fleet address not found for chain ${chainId} protocol ${protocol}`)
  }

  return protocolConfig.satelliteFleetAddress as Address
}

/**
 * Get full protocol configuration for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns Protocol configuration object
 * @throws Error if not found
 */
export function getProtocolConfig(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
) {
  const destination = config.destinations.find((d) => d.chainId === chainId)
  if (!destination) {
    throw new Error(`No destination found for chain ${chainId} in cross-chain config`)
  }

  const protocolConfig = destination.protocols.find((p) => p.protocol === protocol)
  if (!protocolConfig) {
    throw new Error(`Protocol ${protocol} not found for chain ${chainId}`)
  }

  return protocolConfig
}

/**
 * Get destination configuration for a specific chain
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @returns Destination configuration object
 * @throws Error if not found
 */
export function getDestinationConfig(config: CrossChainConfig, chainId: number) {
  const destination = config.destinations.find((d) => d.chainId === chainId)
  if (!destination) {
    throw new Error(`No destination found for chain ${chainId} in cross-chain config`)
  }
  return destination
}

/**
 * Safe getter for FleetProxy address (returns undefined if not found)
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns FleetProxy address or undefined
 */
export function getFleetProxyAddressSafe(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): Address | undefined {
  try {
    return getFleetProxyAddress(config, chainId, protocol)
  } catch {
    return undefined
  }
}

/**
 * Safe getter for CrossChainArk address (returns undefined if not found)
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns CrossChainArk address or undefined
 */
export function getCrossChainArkAddressSafe(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): Address | undefined {
  try {
    return getCrossChainArkAddress(config, chainId, protocol)
  } catch {
    return undefined
  }
}

/**
 * Safe getter for satellite fleet address (returns undefined if not found)
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns Satellite fleet address or undefined
 */
export function getSatelliteFleetAddressSafe(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): Address | undefined {
  try {
    return getSatelliteFleetAddress(config, chainId, protocol)
  } catch {
    return undefined
  }
}

/**
 * Safe getter for protocol configuration (returns undefined if not found)
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns Protocol configuration or undefined
 */
export function getProtocolConfigSafe(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
) {
  try {
    return getProtocolConfig(config, chainId, protocol)
  } catch {
    return undefined
  }
}

/**
 * Check if FleetProxy address exists for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns True if FleetProxy address exists
 */
export function hasFleetProxyAddress(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): boolean {
  return getFleetProxyAddressSafe(config, chainId, protocol) !== undefined
}

/**
 * Check if CrossChainArk address exists for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns True if CrossChainArk address exists
 */
export function hasCrossChainArkAddress(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): boolean {
  return getCrossChainArkAddressSafe(config, chainId, protocol) !== undefined
}

/**
 * Get all destination chain IDs from the configuration
 * @param config Cross-chain configuration
 * @returns Array of chain IDs
 */
export function getAllDestinationChainIds(config: CrossChainConfig): number[] {
  return config.destinations.map((dest) => dest.chainId)
}

/**
 * Get all protocols for a specific chain
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @returns Array of protocol names
 * @throws Error if chain not found
 */
export function getProtocolsForChain(config: CrossChainConfig, chainId: number): string[] {
  const destination = getDestinationConfig(config, chainId)
  return destination.protocols.map((p) => p.protocol)
}

/**
 * Check if a destination chain exists in the configuration
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @returns True if destination exists
 */
export function hasDestinationChain(config: CrossChainConfig, chainId: number): boolean {
  return config.destinations.some((dest) => dest.chainId === chainId)
}

/**
 * Get the source chain ID from the configuration
 * @param config Cross-chain configuration
 * @returns Source chain ID
 * @throws Error if not set
 */
export function getSourceChainId(config: CrossChainConfig): number {
  if (!config.sourceChainId || config.sourceChainId === 0) {
    throw new Error('Source chain ID not set in cross-chain config')
  }
  return config.sourceChainId
}

/**
 * Get the hub fleet address from the configuration
 * @param config Cross-chain configuration
 * @returns Hub fleet address
 * @throws Error if not set
 */
export function getHubFleetAddress(config: CrossChainConfig): Address {
  if (!config.hubFleetAddress) {
    throw new Error('Hub fleet address not set in cross-chain config')
  }
  return config.hubFleetAddress as Address
}

/**
 * Get the hub fleet name from the configuration
 * @param config Cross-chain configuration
 * @returns Hub fleet name
 * @throws Error if not set
 */
export function getHubFleetName(config: CrossChainConfig): string {
  if (!config.hubFleetName) {
    throw new Error('Hub fleet name not set in cross-chain config')
  }
  return config.hubFleetName
}

/**
 * Get cross-chain asset address for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns Asset address
 * @throws Error if not found
 */
export function getCrossChainAssetAddress(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): Address {
  const protocolConfig = getProtocolConfig(config, chainId, protocol)
  if (!protocolConfig?.assetAddress) {
    throw new Error(`Asset address not found for chain ${chainId} protocol ${protocol}`)
  }
  return protocolConfig.assetAddress as Address
}

/**
 * Get cross-chain asset symbol for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns Asset symbol
 * @throws Error if not found
 */
export function getCrossChainAssetSymbol(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): string {
  const protocolConfig = getProtocolConfig(config, chainId, protocol)
  if (!protocolConfig?.assetSymbol) {
    throw new Error(`Asset symbol not found for chain ${chainId} protocol ${protocol}`)
  }
  return protocolConfig.assetSymbol
}

/**
 * Get cross-chain asset information for a specific chain and protocol
 * @param config Cross-chain configuration
 * @param chainId Destination chain ID
 * @param protocol Protocol name (default: 'summerfi')
 * @returns Asset information object
 * @throws Error if not found
 */
export function getCrossChainAssetForProtocol(
  config: CrossChainConfig,
  chainId: number,
  protocol: string = 'summerfi',
): { address: Address; symbol: string } {
  const protocolConfig = getProtocolConfig(config, chainId, protocol)
  if (!protocolConfig?.assetAddress || !protocolConfig?.assetSymbol) {
    throw new Error(`Asset information not found for chain ${chainId} protocol ${protocol}`)
  }
  return {
    address: protocolConfig.assetAddress as Address,
    symbol: protocolConfig.assetSymbol,
  }
}
