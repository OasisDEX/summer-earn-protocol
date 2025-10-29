import kleur from 'kleur'
import { Address, WalletClient, getAddress } from 'viem'
import stargateConfig from '../../../config/adapters/stargate.json'
import { writeContractTx } from '../../lib/contracts/transactions'
import { ADDRESS_ZERO } from '../../lib/infrastructure/constants'
import { STARGATE_ADAPTER_ERRORS_ABI, STARGATE_ADD_SUPPORTED_ASSET_ABI } from './abis'
import { StargateConfig } from './config-types'
import { StargateContractValidator } from './stargate-validation-service'
import { BaseConfig } from './types'

/**
 * Contract instance interface for Stargate adapter
 */
export interface StargateAdapterContract {
  read: {
    assetToStargateContract: (args: [Address]) => Promise<string>
  }
}

/**
 * Configuration for asset operations
 */
export interface AssetConfigurationParams {
  stargateAdapter: StargateAdapterContract
  walletClient: WalletClient
  stargateAdapterAddress: Address
  currentChainId: number
  networkConfig: BaseConfig
  validator: StargateContractValidator
}

/**
 * Result of asset configuration operation
 */
export interface AssetConfigurationResult {
  assetsConfigured: number
  errors: string[]
}

/**
 * Add a single asset if not already mapped
 */
export async function addAssetIfNotMapped(
  params: AssetConfigurationParams,
  assetSymbol: string,
  stargateContract: string,
): Promise<{ configured: boolean; error?: string }> {
  const {
    stargateAdapter,
    walletClient,
    stargateAdapterAddress,
    currentChainId,
    networkConfig,
    validator,
  } = params

  // Map 'eth' to 'weth' since network config uses 'weth' but Stargate config uses 'eth'
  const tokenKey = assetSymbol === 'eth' ? 'weth' : assetSymbol
  const localAssetAddress = networkConfig.tokens[tokenKey as keyof typeof networkConfig.tokens]

  if (!localAssetAddress || !stargateContract) {
    return {
      configured: false,
      error: `Asset ${assetSymbol} not available on current chain ${currentChainId} (address: ${localAssetAddress})`,
    }
  }

  try {
    const checksummedLocalAddress = getAddress(localAssetAddress)
    const checksummedStargateContract = getAddress(stargateContract)

    console.log(
      `Configuring asset ${assetSymbol} (${checksummedLocalAddress}) with Stargate contract ${checksummedStargateContract}`,
    )

    // Validate Stargate contract before adding asset
    const isValid = await validator.validateContract(checksummedStargateContract)
    if (!isValid) {
      return {
        configured: false,
        error: `Invalid Stargate contract ${checksummedStargateContract}: Failed validation`,
      }
    }

    // Validate that the Stargate contract's token matches the asset address
    const tokenMatch = await validator.validateTokenMatch(
      checksummedLocalAddress,
      checksummedStargateContract,
    )
    if (!tokenMatch.isValid) {
      return {
        configured: false,
        error: `Error configuring asset mapping for ${assetSymbol}: ${tokenMatch.error}`,
      }
    }

    // Check current chain asset mapping
    const currentStargateContract = String(
      await stargateAdapter.read.assetToStargateContract([checksummedLocalAddress]),
    )

    if (
      currentStargateContract === ADDRESS_ZERO ||
      currentStargateContract.toLowerCase() !== checksummedStargateContract.toLowerCase()
    ) {
      console.log(
        `Adding supported asset ${checksummedLocalAddress} for current chain ${currentChainId}`,
      )

      const hash = await writeContractTx(
        walletClient,
        stargateAdapterAddress,
        STARGATE_ADD_SUPPORTED_ASSET_ABI,
        'addSupportedAsset',
        [checksummedLocalAddress, checksummedStargateContract],
        STARGATE_ADAPTER_ERRORS_ABI,
      )

      console.log(
        kleur.green(
          `Asset mapping for ${checksummedLocalAddress} on current chain added, tx: ${hash}`,
        ),
      )

      return { configured: true }
    } else {
      console.log(kleur.yellow(`Asset mapping for current chain already correct, skipping`))
      return { configured: false }
    }
  } catch (error) {
    const errorMessage = `Error configuring asset mapping for ${assetSymbol}: ${error instanceof Error ? error.message : 'Unknown error'}`
    console.error(kleur.red(errorMessage), error)
    return { configured: false, error: errorMessage }
  }
}

/**
 * Configure supported assets for Stargate adapter
 */
export async function configureSupportedAssets(
  params: AssetConfigurationParams,
): Promise<AssetConfigurationResult> {
  const { currentChainId } = params
  let assetsConfigured = 0
  const errors: string[] = []

  // Get Stargate contracts for current chain
  const currentChainContracts = (stargateConfig as StargateConfig).contracts[
    currentChainId.toString()
  ]

  if (!currentChainContracts) {
    console.log(
      kleur.yellow(
        `No Stargate V2 contracts found for current chain ${currentChainId}, skipping asset configuration`,
      ),
    )
    return { assetsConfigured: 0, errors: [] }
  }

  // Configure supported assets
  for (const [assetSymbol, stargateContract] of Object.entries(currentChainContracts)) {
    if (!stargateContract) {
      continue
    }

    const result = await addAssetIfNotMapped(params, assetSymbol, stargateContract)

    if (result.configured) {
      assetsConfigured++
    } else if (result.error) {
      errors.push(result.error)
    }
  }

  return { assetsConfigured, errors }
}

/**
 * Log asset configuration results
 */
export function logAssetConfigurationResults(result: AssetConfigurationResult): void {
  console.log(kleur.blue(`Configured ${result.assetsConfigured} asset mappings`))

  if (result.errors.length > 0) {
    console.log(kleur.red(`Encountered ${result.errors.length} errors:`))
    result.errors.forEach((error) => console.log(kleur.red(`  - ${error}`)))
  }
}
