import hre from 'hardhat'
import kleur from 'kleur'
import { Address, WalletClient, getAddress } from 'viem'
import stargateConfig from '../../../config/adapters/stargate.json'
import { waitForTransactionConfirmation, writeContractTx } from '../../lib/contracts/transactions'
import { STARGATE_ADD_SUPPORTED_ASSET_ABI } from './abis'
import { StargateConfig } from './config-types'
import { AdapterConfigurationError, AdapterValidationError } from './errors'
import { BaseConfig } from './types'
import { StargateContractValidator } from './stargate-validation-service'

/**
 * Configuration for asset operations
 */
export interface AssetConfigurationParams {
  stargateAdapter: any
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
  const { stargateAdapter, walletClient, stargateAdapterAddress, currentChainId, networkConfig, validator } = params

  const tokenKey = assetSymbol === 'eth' ? 'weth' : assetSymbol
  const localAssetAddress = networkConfig.tokens[tokenKey as keyof typeof networkConfig.tokens]

  if (!localAssetAddress || !stargateContract) {
    return {
      configured: false,
      error: `Asset ${assetSymbol} not available on current chain ${currentChainId} (address: ${localAssetAddress})`
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
        error: `Invalid Stargate contract ${checksummedStargateContract}: Failed validation`
      }
    }

    // Check current chain asset mapping
    const currentStargateContract = String(
      await stargateAdapter.read.assetToStargateContract([checksummedLocalAddress]),
    )

    if (
      currentStargateContract === '0x0000000000000000000000000000000000000000' ||
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
    result.errors.forEach(error => console.log(kleur.red(`  - ${error}`)))
  }
}
