import hre from 'hardhat'
import { createPublicClient, http } from 'viem'
import { arbitrum, base, mainnet } from 'viem/chains'
import { getConfigByNetwork } from './config-handler'

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
  sonic: {
    id: 146,
    name: 'Sonic',
    network: 'sonic',
    nativeCurrency: { name: 'S', symbol: 'S', decimals: 18 },
    rpcUrls: { default: { http: [RPC_URL_MAP.sonic] } },
  },
}

/**
 * Get a public client for a specific chain
 * @param chainName The name of the chain
 * @returns A public client configured for the specified chain
 */
export async function getChainPublicClient(chainName: string) {
  // If it's the current chain, use the Hardhat client
  if (chainName === hre.network.name) {
    return await hre.viem.getPublicClient()
  }

  // Get the RPC URL for the chain
  const rpcUrl = RPC_URL_MAP[chainName as keyof typeof RPC_URL_MAP]

  if (!rpcUrl) {
    throw new Error(
      `No RPC URL found for chain ${chainName}. Set RPC_URL_${chainName.toUpperCase()} environment variable.`,
    )
  }

  // Get chain configuration
  let chainConfig
  try {
    // First check if we have a predefined Viem chain config
    chainConfig = CHAIN_CONFIG_MAP[chainName as keyof typeof CHAIN_CONFIG_MAP]

    // If not, try to create one from our network config
    if (!chainConfig) {
      const config = getConfigByNetwork(chainName, { common: true }, false)
      chainConfig = {
        id: Number(config.common.chainId),
        name: chainName,
        network: chainName,
        nativeCurrency: { name: chainName, symbol: chainName.substring(0, 1), decimals: 18 },
        rpcUrls: {
          default: { http: [rpcUrl] },
          public: { http: [rpcUrl] },
        },
      }
    }
  } catch (error: any) {
    throw new Error(`Failed to get chain configuration for ${chainName}: ${error.message}`)
  }

  // Create a public client for the specified chain
  return createPublicClient({
    chain: chainConfig,
    transport: http(rpcUrl),
  })
}
