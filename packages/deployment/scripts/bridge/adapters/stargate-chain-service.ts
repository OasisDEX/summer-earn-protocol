import kleur from 'kleur'
import { Address, WalletClient } from 'viem'
import { waitForTransactionConfirmation, writeContractTx } from '../../lib/contracts/transactions'
import { STARGATE_ADD_SUPPORTED_CHAIN_ABI } from './abis'
import { ChainInfo, NetworkConfigMap } from './types'
import { getNetworkNameFromChainId } from './utils'

/**
 * Configuration for chain operations
 */
export interface ChainConfigurationParams {
  stargateAdapter: any
  walletClient: WalletClient
  stargateAdapterAddress: Address
  currentChainId: number
  supportedChains: ChainInfo[]
  allNetworkConfigs?: NetworkConfigMap
}

/**
 * Result of chain configuration operation
 */
export interface ChainConfigurationResult {
  chainsAdded: number
  errors: string[]
}

/**
 * Add a single chain if not already supported
 */
export async function addChainIfNotSupported(
  params: ChainConfigurationParams,
  chainInfo: ChainInfo,
): Promise<{ added: boolean; error?: string }> {
  const {
    stargateAdapter,
    walletClient,
    stargateAdapterAddress,
    currentChainId,
    allNetworkConfigs,
  } = params

  if (chainInfo.chainId === currentChainId) {
    return { added: false } // Skip current chain
  }

  try {
    // Check if chain is already supported
    let existingEndpointId = 0
    try {
      existingEndpointId = Number(await stargateAdapter.read.chainToEndpointId([chainInfo.chainId]))
    } catch (error) {
      console.log(`Chain ${chainInfo.chainId} not yet supported, will add it`)
      existingEndpointId = 0
    }

    if (existingEndpointId === 0) {
      console.log(
        `Adding supported chain ${chainInfo.chainId} with LayerZero endpoint ID ${chainInfo.endpointId}`,
      )

      const adapterAddress = await determineAdapterAddress(
        chainInfo,
        currentChainId,
        stargateAdapterAddress,
        allNetworkConfigs,
      )

      if (!adapterAddress) {
        return {
          added: false,
          error: `No adapter address found for chain ${chainInfo.chainId}`,
        }
      }

      const hash = await writeContractTx(
        walletClient,
        stargateAdapterAddress,
        STARGATE_ADD_SUPPORTED_CHAIN_ABI,
        'addSupportedChain',
        [chainInfo.chainId, chainInfo.endpointId, adapterAddress],
      )

      console.log(kleur.green(`Chain ${chainInfo.chainId} added successfully, tx: ${hash}`))
      await waitForTransactionConfirmation(hash)
      console.log(kleur.green(`Chain ${chainInfo.chainId} transaction confirmed`))

      return { added: true }
    } else {
      console.log(kleur.yellow(`Chain ${chainInfo.chainId} already supported, skipping`))
      return { added: false }
    }
  } catch (error) {
    const errorMessage = `Error adding chain ${chainInfo.chainId}: ${error instanceof Error ? error.message : 'Unknown error'}`
    console.error(kleur.red(errorMessage), error)
    return { added: false, error: errorMessage }
  }
}

/**
 * Determine the adapter address for a given chain
 */
export async function determineAdapterAddress(
  chainInfo: ChainInfo,
  currentChainId: number,
  stargateAdapterAddress: Address,
  allNetworkConfigs?: NetworkConfigMap,
): Promise<Address | null> {
  if (chainInfo.chainId === currentChainId) {
    return stargateAdapterAddress
  }

  const targetNetworkName = getNetworkNameFromChainId(chainInfo.chainId)
  const targetNetworkConfig = allNetworkConfigs?.[targetNetworkName]
  const existingAdapterAddress =
    targetNetworkConfig?.deployedContracts?.bridge?.adapters?.stargate?.address

  if (
    existingAdapterAddress &&
    existingAdapterAddress !== '0x0000000000000000000000000000000000000000'
  ) {
    console.log(
      `Using existing adapter address for chain ${chainInfo.chainId}: ${existingAdapterAddress}`,
    )
    return existingAdapterAddress as Address
  } else {
    console.log(`No adapter address found for chain ${chainInfo.chainId}, skipping for now`)
    return null
  }
}

/**
 * Configure supported chains for Stargate adapter
 */
export async function configureSupportedChains(
  params: ChainConfigurationParams,
): Promise<ChainConfigurationResult> {
  const { supportedChains } = params
  let chainsAdded = 0
  const errors: string[] = []

  for (const chainInfo of supportedChains) {
    const result = await addChainIfNotSupported(params, chainInfo)

    if (result.added) {
      chainsAdded++
    } else if (result.error) {
      errors.push(result.error)
    }
  }

  return { chainsAdded, errors }
}

/**
 * Log chain configuration results
 */
export function logChainConfigurationResults(result: ChainConfigurationResult): void {
  console.log(kleur.green(`Added ${result.chainsAdded} new supported chains`))

  if (result.errors.length > 0) {
    console.log(kleur.red(`Encountered ${result.errors.length} errors:`))
    result.errors.forEach((error) => console.log(kleur.red(`  - ${error}`)))
  }
}
