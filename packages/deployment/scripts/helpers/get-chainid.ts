import hre from 'hardhat'

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
