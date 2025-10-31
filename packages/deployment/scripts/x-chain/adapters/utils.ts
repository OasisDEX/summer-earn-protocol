import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import { CHAIN_CONFIG_MAP, RPC_URL_MAP, getChainConfigs } from '../../lib/chain/config'
import { getChainNameById } from '../../lib/chain/helpers'
import { isTenderlyVirtualTestnet } from '../../lib/infrastructure/tenderly'
import { createClients } from '../../lib/infrastructure/wallet'
import { BaseConfig, ChainInfo, NetworkConfigMap } from './types'

/**
 * Helper function to get all supported chains with LayerZero endpoint IDs from config
 */
export function getSupportedChainsFromConfig(allNetworkConfigs?: NetworkConfigMap): ChainInfo[] {
  if (!allNetworkConfigs) {
    // Get chains from our standard chain configs
    const configs = getChainConfigs()

    return Object.values(configs)
      .filter(({ config }) => config.common?.layerZero?.eID)
      .map(({ chain, config }) => ({
        chainId: chain.id,
        endpointId: Number(config.common.layerZero.eID),
      }))
  }

  // Extract from provided config
  const chains: ChainInfo[] = []
  for (const [, config] of Object.entries(allNetworkConfigs)) {
    const baseConfig = config as BaseConfig
    if (baseConfig?.common?.chainId && baseConfig?.common?.layerZero?.eID) {
      chains.push({
        chainId: Number(baseConfig.common.chainId),
        endpointId: Number(baseConfig.common.layerZero.eID),
      })
    }
  }

  return chains
}

/**
 * Get wallet client for transactions using the proper private key setup
 */
export async function getWalletClient() {
  const networkName = hre.network.name
  const rpcUrl = RPC_URL_MAP[networkName as keyof typeof RPC_URL_MAP]
  const chainConfig = CHAIN_CONFIG_MAP[networkName as keyof typeof CHAIN_CONFIG_MAP]

  if (!rpcUrl) {
    throw new Error(`RPC URL not found for network ${networkName}`)
  }

  if (!chainConfig) {
    throw new Error(`Chain configuration not found for ${networkName}`)
  }

  const { walletClient } = createClients(chainConfig, rpcUrl)
  return walletClient
}

/**
 * Helper function to get network name from chain ID
 */
export function getNetworkNameFromChainId(chainId: number): string {
  return getChainNameById(chainId)
}

/**
 * Check if adapter is already registered with bridge router
 */
export async function isAdapterRegistered(
  bridgeRouterAddress: Address,
  adapterAddress: Address,
): Promise<boolean> {
  try {
    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as string,
      getAddress(bridgeRouterAddress as `0x${string}`),
    )

    return Boolean(
      await bridgeRouter.read.isValidAdapter([getAddress(adapterAddress as `0x${string}`)]),
    )
  } catch (error) {
    console.error(kleur.red('Error checking if adapter is registered:'), error)
    return false
  }
}

/**
 * Wait for pending transactions to be confirmed
 */
export async function waitForPendingTransactions(
  requiredConfirmations = 5,
  checkIntervalMs = 5000,
  maxAttempts = 24,
): Promise<void> {
  // Check if we're on Tenderly virtual testnet
  const isTenderly = isTenderlyVirtualTestnet()

  if (isTenderly) {
    console.log(kleur.yellow('Detected Tenderly virtual testnet, skipping confirmation wait'))
    return
  }

  const [deployer] = await hre.viem.getWalletClients()
  const provider = await hre.viem.getPublicClient()
  const address = deployer.account.address

  console.log(kleur.yellow(`Checking for pending transactions from ${address}...`))

  let attempts = 0
  while (attempts < maxAttempts) {
    try {
      // Get the current nonce
      const currentNonce = await provider.getTransactionCount({ address })

      // Get the pending nonce
      const pendingNonce = await provider.getTransactionCount({
        address,
        blockTag: 'pending',
      })

      // First check if there are any pending transactions
      if (currentNonce !== pendingNonce) {
        console.log(
          kleur.yellow(
            `Waiting for ${pendingNonce - currentNonce} transactions to be mined (${attempts + 1}/${maxAttempts})...`,
          ),
        )
        await new Promise((resolve) => setTimeout(resolve, checkIntervalMs))
        attempts++
        continue
      }

      // Now check if recent transactions have enough confirmations
      const latestBlock = await provider.getBlockNumber()

      // Check transactions from recent blocks to see if any are from our deployer
      let hasRecentTransactions = false

      // Look back a few blocks to find recent transactions from this address
      for (let i = 0; i < Math.min(5, Number(latestBlock)); i++) {
        const blockNumber = latestBlock - BigInt(i)
        try {
          const block = await provider.getBlock({ blockNumber, includeTransactions: true })

          if (block.transactions) {
            for (const tx of block.transactions) {
              if (typeof tx === 'object' && tx.from?.toLowerCase() === address.toLowerCase()) {
                const confirmations = Number(latestBlock - blockNumber) + 1
                if (confirmations < requiredConfirmations) {
                  console.log(
                    kleur.yellow(
                      `Transaction ${tx.hash} has ${confirmations}/${requiredConfirmations} confirmations (${attempts + 1}/${maxAttempts})...`,
                    ),
                  )
                  hasRecentTransactions = true
                  break
                }
              }
            }
          }
        } catch (error) {
          // If we can't get a block, just continue
          continue
        }

        if (hasRecentTransactions) break
      }

      if (!hasRecentTransactions) {
        console.log(
          kleur.green('All recent transactions have sufficient confirmations, continuing...'),
        )
        return
      }

      // Wait for the specified interval
      await new Promise((resolve) => setTimeout(resolve, checkIntervalMs))
      attempts++
    } catch (error) {
      console.error(kleur.red('Error checking pending transactions:'), error)
      attempts++
      // Continue anyway, but log the error
    }
  }

  console.log(kleur.yellow('Max wait time reached, proceeding anyway...'))
}
