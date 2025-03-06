import hre from 'hardhat'
import kleur from 'kleur'

/**
 * Checks if the current RPC URL is a Tenderly virtual testnet.
 *
 * @returns {boolean} True if the RPC URL is a Tenderly virtual testnet, false otherwise.
 */
export function isTenderlyVirtualTestnet(): boolean {
  try {
    // Get the provider URL from the Hardhat Runtime Environment
    const provider = hre.network.config.url as string

    if (!provider) {
      return false
    }

    // Check if the URL matches the Tenderly virtual testnet pattern
    // Typical URL: https://virtual.base.rpc.tenderly.co/e28fd0a9-bb84-4a41-8fe6-01fbb13a4121
    return (
      provider.includes('virtual') &&
      provider.includes('rpc.tenderly.co') &&
      /[a-f0-9-]{36}/.test(provider)
    ) // UUID format check
  } catch (error) {
    console.warn(kleur.yellow('Error checking for Tenderly virtual testnet:'), error)
    return false
  }
}

/**
 * Logs a warning if the current RPC is a Tenderly virtual testnet.
 *
 * @param {string} [message] - Optional custom warning message.
 * @returns {boolean} True if the RPC URL is a Tenderly virtual testnet, false otherwise.
 */
export function warnIfTenderlyVirtualTestnet(message?: string): boolean {
  const isTenderly = isTenderlyVirtualTestnet()

  if (isTenderly) {
    console.warn(
      kleur.bgYellow().black().bold(' TENDERLY VIRTUAL TESTNET DETECTED '),
      '\n',
      kleur.yellow(
        message ||
          'You are using a Tenderly virtual testnet. This environment is ephemeral and any deployments will be lost when the session ends.',
      ),
    )
  }

  return isTenderly
}

/**
 * Gets the Tenderly virtual testnet ID from the RPC URL if available.
 *
 * @returns {string|null} The Tenderly virtual testnet ID, or null if not a Tenderly virtual testnet.
 */
export function getTenderlyVirtualTestnetId(): string | null {
  try {
    const provider = hre.network.config.url as string

    if (!provider || !isTenderlyVirtualTestnet()) {
      return null
    }

    // Extract the UUID from the URL
    const match = provider.match(/([a-f0-9-]{36})/)
    return match ? match[1] : null
  } catch (error) {
    console.warn(kleur.yellow('Error extracting Tenderly virtual testnet ID:'), error)
    return null
  }
}
