import hre from 'hardhat'

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
}

/**
 * Get the chain ID from the Hardhat Runtime Environment.
 * @returns {number} The chain ID.
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
 * @param {string} network - The network name (e.g., 'mainnet', 'goerli', 'polygon')
 * @returns {number} The chain ID for the specified network
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
