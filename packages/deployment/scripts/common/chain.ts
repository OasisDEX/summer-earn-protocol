import hre from 'hardhat'
import { Address } from 'viem'
import { arbitrum, base, mainnet, sonic } from 'viem/chains'
import prodConfig from '../../config/index.json'
import testConfig from '../../config/index.test.json'
import type { BaseConfig } from '../../types/config-types'
// Note: getConfigByNetwork import removed to avoid circular dependency
// Import it locally where needed

// Centralized RPC URL mapping
export const RPC_URL_MAP = {
  mainnet: process.env.MAINNET_RPC_URL,
  base: process.env.BASE_RPC_URL,
  arbitrum: process.env.ARBITRUM_RPC_URL,
  sonic: process.env.SONIC_RPC_URL,
}

// Standard chain mapping
export const CHAIN_CONFIG_MAP = {
  mainnet,
  base,
  arbitrum,
  sonic: sonic,
}

export const CHAIN_MAP_BY_ID = Object.fromEntries(
  Object.values(CHAIN_CONFIG_MAP).map((chain) => [chain.id, chain]),
)

/**
 * Map of network names to their chain IDs
 */
const NETWORK_TO_CHAIN_ID: Record<string, number> = {
  // Mainnets
  mainnet: 1,
  ethereum: 1,
  polygon: 137,
  arbitrum: 42161,
  base: 8453,
  sonic: 146,
}

export type ChainName = 'base' | 'arbitrum' | 'mainnet' | 'sonic'

/**
 * Gets the configuration for all supported chains
 * @param useTestConfig Whether to use test configuration
 * @returns Chain configurations
 */
export function getChainConfigs(useTestConfig: boolean = false) {
  const config = useTestConfig ? testConfig : prodConfig

  return {
    base: {
      chain: CHAIN_CONFIG_MAP.base,
      config: config.base as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.base as string,
    },
    arbitrum: {
      chain: CHAIN_CONFIG_MAP.arbitrum,
      config: config.arbitrum as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.arbitrum as string,
    },
    mainnet: {
      chain: CHAIN_CONFIG_MAP.mainnet,
      config: config.mainnet as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.mainnet as string,
    },
    sonic: {
      chain: CHAIN_CONFIG_MAP.sonic,
      config: config.sonic as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.sonic as string,
    },
  } as const
}

/**
 * Gets chain configuration by chain name
 * @param chainName The chain name
 * @param useTestConfig Whether to use test configuration
 * @returns Chain configuration
 */
export function getChainConfigByChainName(chainName: ChainName, useTestConfig: boolean = false) {
  const configs = getChainConfigs(useTestConfig)
  const config = configs[chainName]
  if (!config) throw new Error(`Chain config not found for ${chainName}`)
  return config
}

/**
 * Gets chain configuration by chain ID
 * @param chainId The chain ID
 * @param useTestConfig Whether to use test configuration
 * @returns Chain name and configuration
 */
export function getChainConfigByChainId(chainId: number, useTestConfig: boolean = false) {
  const configs = getChainConfigs(useTestConfig)
  const chainEntries = Object.entries(configs)

  const match = chainEntries.find(([_, config]) => config.chain.id === chainId)
  if (!match) {
    throw new Error(`Chain config not found for chain ID: ${chainId}`)
  }

  const [chainName, chainConfig] = match
  return { chainName: chainName as ChainName, chainConfig }
}

/**
 * Gets the chain name based on chain ID
 * @param chainId The chain ID to look up
 * @returns The name of the chain
 */
export function getChainNameById(chainId: number): string {
  const chainName = CHAIN_MAP_BY_ID[chainId]?.name
  if (!chainName) {
    throw new Error(`Chain name not found for chain ID: ${chainId}`)
  }

  return chainName
}

/**
 * Get the chain ID from the Hardhat Runtime Environment.
 * @returns The chain ID
 */
export function getChainId(): number {
  const chainId = hre.network.config.chainId || hre.network.provider.send('eth_chainId')
  if (typeof chainId === 'string') {
    return parseInt(chainId, 16)
  }
  if (typeof chainId === 'number') {
    return chainId
  }
  throw new Error('Unable to determine chain ID')
}

/**
 * Get the chain ID for a given network name.
 * @param network The network name (e.g., 'mainnet', 'goerli', 'polygon')
 * @returns The chain ID for the specified network
 * @throws {Error} If the network is not supported
 */
export function getChainIdByNetwork(network: string): number {
  const networkLower = network.toLowerCase()
  const chainId = NETWORK_TO_CHAIN_ID[networkLower]

  if (chainId === undefined) {
    throw new Error(
      `Unsupported network: ${network}. Supported networks are: ${Object.keys(NETWORK_TO_CHAIN_ID).join(', ')}`,
    )
  }

  return chainId
}

/**
 * Gets chain ID from network name or the current network
 * @param networkName Optional network name
 * @returns The chain ID
 */
export function getChainIdFromNetwork(networkName?: string): number {
  if (networkName) {
    return getChainIdByNetwork(networkName)
  }

  const network = hre.network.name

  const chainId = CHAIN_MAP_BY_ID[network as keyof typeof CHAIN_MAP_BY_ID]?.id

  if (!chainId) {
    throw new Error(`Unknown network name: ${network}`)
  }

  return chainId
}

/**
 * Gets the hub chain ID from the SummerGovernor contract and determines if
 * the current chain is the hub chain
 * @returns An object containing the hubChainId and whether the current chain is the hub chain
 */
export async function getHubChainInfo() {
  // Import locally to avoid circular dependency
  const { getConfigByNetwork } = await import('./config')
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: false })

  // Get the SummerGovernor contract
  const summerGovernor = await hre.viem.getContractAt(
    'SummerGovernor' as string,
    config.deployedContracts.gov.summerGovernor.address as Address,
  )

  // Read the hub chain ID from the contract
  const hubChainId = await summerGovernor.read.hubChainId()

  // Determine if we're on the hub chain
  const currentChainId = hre.network.config.chainId
  const isHubChain = hubChainId === currentChainId

  return {
    hubChainId,
    isHubChain,
    hubChainName: getChainNameById(hubChainId as number),
    currentChainId,
    currentChainName: hre.network.name,
  }
}
