import hre from 'hardhat'
import { Chain, createPublicClient, http } from 'viem'
import { CHAIN_CONFIG_MAP, RPC_URL_MAP } from '../common/chain-config-map'

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
  const chainConfig = CHAIN_CONFIG_MAP[chainName as keyof typeof CHAIN_CONFIG_MAP]

  if (!chainConfig) {
    throw new Error(`Chain configuration not found for ${chainName}`)
  }

  // Create a public client for the specified chain
  return createPublicClient({
    chain: chainConfig as Chain,
    transport: http(rpcUrl),
  })
}
