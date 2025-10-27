import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import stargateConfig from '../../../config/adapters/stargate.json'
import StargateAdapterModule from '../../../ignition/modules/adapters/stargate'
import {
  BRIDGE_ROUTER_REGISTER_ADAPTER_ABI,
  STARGATE_ADD_SUPPORTED_ASSET_ABI,
  STARGATE_ADD_SUPPORTED_CHAIN_ABI,
  STARGATE_COMMON_ABI,
  STARGATE_OFT_ABI,
  STARGATE_POOL_ABI,
  STARGATE_UPDATE_CHAIN_ADAPTER_ABI,
} from './abis'
import {
  isAdapterRegistered,
  validateBridgeConfig,
  waitForTransactionConfirmation,
  writeContractTx,
} from './transaction-helpers'
import { BaseConfig, ChainInfo } from './types'
import {
  extractBridgeRouterAddress,
  getNetworkNameFromChainId,
  getSupportedChainsFromConfig,
  getWalletClient,
} from './utils'

// Define a type for the bridge router address parameter
type BridgeRouterAddressParam = Address | { bridgeRouterAddress: Address }

// Cache for validated contracts
const validatedContracts = new Set<string>()

/**
 * Deploy Stargate adapter using Ignition module
 */
export async function deployStargateAdapter(
  networkConfig: BaseConfig,
  allNetworkConfigs?: Record<string, BaseConfig>,
): Promise<Address> {
  console.log(kleur.blue('Deploying Stargate V2 adapter using Ignition module'))

  // Get current chain ID
  const chainId = Number(networkConfig.common.chainId)

  // Get the crossChainRegistry address from network config
  const crossChainRegistry = networkConfig.deployedContracts.bridge?.crossChainRegistry?.address
  if (!crossChainRegistry) {
    throw new Error(`CrossChainRegistry address not found in config for chain ID ${chainId}`)
  }

  // Get the access manager address from network config
  const accessManager = networkConfig.deployedContracts.gov.protocolAccessManager.address
  if (!accessManager) {
    throw new Error(`ProtocolAccessManager address not found in config for chain ID ${chainId}`)
  }

  // Get LayerZero endpoint from network config
  const lzEndpoint = networkConfig.common.layerZero.lzEndpoint
  if (!lzEndpoint) {
    throw new Error(`LayerZero endpoint not configured for chain ID ${chainId}`)
  }

  // Get HarborCommand address from network config
  const harborCommand = networkConfig.deployedContracts.core.harborCommand.address
  if (!harborCommand) {
    throw new Error(`HarborCommand address not found in config for chain ID ${chainId}`)
  }

  // Deploy using Ignition module - all 4 constructor parameters needed
  const deploymentResult = await hre.ignition.deploy(StargateAdapterModule, {
    parameters: {
      StargateAdapterModule: {
        crossChainRegistry,
        accessManager,
        lzEndpoint,
        harborCommand,
      },
    },
  })

  const stargateAdapterAddress = deploymentResult.stargateAdapter.address as Address
  console.log(kleur.green(`StargateAdapter V2 deployed at: ${stargateAdapterAddress}`))

  return stargateAdapterAddress
}

/**
 * Configure supported chains for Stargate adapter
 */
async function configureSupportedChains(
  stargateAdapter: any,
  walletClient: any,
  stargateAdapterAddress: Address,
  currentChainId: number,
  supportedChains: ChainInfo[],
  allNetworkConfigs?: Record<string, BaseConfig>,
): Promise<number> {
  let chainsAdded = 0

  for (const chainInfo of supportedChains) {
    if (chainInfo.chainId === currentChainId) {
      continue // Skip current chain
    }

    try {
      // Check if chain is already supported
      let existingEndpointId = 0
      try {
        existingEndpointId = Number(
          await stargateAdapter.read.chainToEndpointId([chainInfo.chainId]),
        )
      } catch (error) {
        console.log(`Chain ${chainInfo.chainId} not yet supported, will add it`)
        existingEndpointId = 0
      }

      if (existingEndpointId === 0) {
        console.log(
          `Adding supported chain ${chainInfo.chainId} with LayerZero endpoint ID ${chainInfo.endpointId}`,
        )

        // Determine adapter address for this chain
        let adapterAddress: Address

        if (chainInfo.chainId === currentChainId) {
          adapterAddress = stargateAdapterAddress
        } else {
          const targetNetworkName = getNetworkNameFromChainId(chainInfo.chainId)
          const targetNetworkConfig = allNetworkConfigs?.[targetNetworkName]
          const existingAdapterAddress =
            targetNetworkConfig?.deployedContracts?.bridge?.adapters?.stargate?.address

          if (
            existingAdapterAddress &&
            existingAdapterAddress !== '0x0000000000000000000000000000000000000000'
          ) {
            adapterAddress = existingAdapterAddress as Address
            console.log(
              `Using existing adapter address for chain ${chainInfo.chainId}: ${adapterAddress}`,
            )
          } else {
            console.log(`No adapter address found for chain ${chainInfo.chainId}, skipping for now`)
            continue
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
        chainsAdded++
      } else {
        console.log(kleur.yellow(`Chain ${chainInfo.chainId} already supported, skipping`))
      }
    } catch (error) {
      console.error(kleur.red(`Error adding chain ${chainInfo.chainId}:`), error)
    }
  }

  return chainsAdded
}

/**
 * Configure supported assets for Stargate adapter
 */
async function configureSupportedAssets(
  stargateAdapter: any,
  walletClient: any,
  stargateAdapterAddress: Address,
  currentChainId: number,
  networkConfig: BaseConfig,
): Promise<number> {
  let assetsConfigured = 0

  // Get Stargate contracts for current chain
  const currentChainContracts = (stargateConfig.contracts as any)[currentChainId.toString()]
  if (!currentChainContracts) {
    console.log(
      kleur.yellow(
        `No Stargate V2 contracts found for current chain ${currentChainId}, skipping asset configuration`,
      ),
    )
    return 0
  }

  // Configure supported assets
  for (const [assetSymbol, stargateContract] of Object.entries(currentChainContracts)) {
    const tokenKey = assetSymbol === 'eth' ? 'weth' : assetSymbol
    const localAssetAddress = networkConfig.tokens[tokenKey as keyof typeof networkConfig.tokens]

    if (localAssetAddress && stargateContract) {
      const checksummedLocalAddress = getAddress(localAssetAddress)
      const checksummedStargateContract = getAddress(stargateContract as string)

      console.log(
        `Configuring asset ${assetSymbol} (${checksummedLocalAddress}) with Stargate contract ${checksummedStargateContract}`,
      )

      // Validate Stargate contract before adding asset (with caching)
      const contractKey = `${currentChainId}-${checksummedStargateContract}`
      if (!validatedContracts.has(contractKey)) {
        try {
          const isValid = await validateStargateContract(checksummedStargateContract)
          if (!isValid) {
            console.error(
              kleur.red(
                `Invalid Stargate contract ${checksummedStargateContract}: Failed validation`,
              ),
            )
            continue
          }
          validatedContracts.add(contractKey)
          console.log(kleur.green(`✓ Stargate contract ${checksummedStargateContract} validated`))
        } catch (error) {
          console.error(
            kleur.red(`Error validating Stargate contract ${checksummedStargateContract}:`),
            error,
          )
          continue
        }
      } else {
        console.log(
          kleur.blue(`✓ Stargate contract ${checksummedStargateContract} already validated`),
        )
      }

      // Check current chain asset mapping
      try {
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
          assetsConfigured++
        } else {
          console.log(kleur.yellow(`Asset mapping for current chain already correct, skipping`))
        }
      } catch (error) {
        console.error(kleur.red(`Error configuring asset mapping for current chain:`), error)
      }
    } else {
      console.log(
        kleur.yellow(
          `Asset ${assetSymbol} not available on current chain ${currentChainId} (address: ${localAssetAddress}), skipping`,
        ),
      )
    }
  }

  return assetsConfigured
}

/**
 * Register adapter with bridge router
 */
async function registerWithBridgeRouter(
  walletClient: any,
  stargateAdapterAddress: Address,
  bridgeRouterAddress: BridgeRouterAddressParam,
): Promise<void> {
  try {
    const actualAddress = extractBridgeRouterAddress(bridgeRouterAddress)
    const alreadyRegistered = await isAdapterRegistered(actualAddress, stargateAdapterAddress)

    if (!alreadyRegistered) {
      const hash = await writeContractTx(
        walletClient,
        actualAddress,
        BRIDGE_ROUTER_REGISTER_ADAPTER_ABI,
        'registerAdapter',
        [getAddress(stargateAdapterAddress as `0x${string}`)],
      )
      console.log(kleur.green(`Stargate V2 adapter registered with bridge router, tx: ${hash}`))
    } else {
      console.log(
        kleur.yellow(
          `Stargate V2 adapter already registered with bridge router, skipping registration`,
        ),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error registering adapter with bridge router:'), error)
  }
}
/**
 * Configure supported chains and assets for Stargate V2 adapter
 */
export async function configureStargateAdapter(
  stargateAdapterAddress: Address,
  bridgeRouterAddress: BridgeRouterAddressParam,
  networkConfig: BaseConfig,
  allNetworkConfigs?: Record<string, BaseConfig>,
): Promise<void> {
  console.log(kleur.blue('Configuring Stargate V2 adapter'))

  validateBridgeConfig(networkConfig)

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  const walletClient = await getWalletClient()
  const currentChainId = Number(networkConfig.common.chainId)
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  // Debug logging
  console.log(
    'allNetworkConfigs keys:',
    allNetworkConfigs ? Object.keys(allNetworkConfigs) : 'undefined',
  )
  console.log('supportedChains:', supportedChains)

  // Configure supported chains
  const chainsAdded = await configureSupportedChains(
    stargateAdapter,
    walletClient,
    stargateAdapterAddress,
    currentChainId,
    supportedChains,
    allNetworkConfigs,
  )

  console.log(kleur.green(`Added ${chainsAdded} new supported chains`))

  // Only add delay if we actually added chains
  if (chainsAdded > 0) {
    console.log(kleur.blue(`Added ${chainsAdded} new chains, waiting for settlement...`))
    await new Promise((resolve) => setTimeout(resolve, 2000))
  }

  // Configure supported assets
  const assetsConfigured = await configureSupportedAssets(
    stargateAdapter,
    walletClient,
    stargateAdapterAddress,
    currentChainId,
    networkConfig,
  )

  console.log(kleur.blue(`Configured ${assetsConfigured} asset mappings`))

  // Register adapter with bridge router
  await registerWithBridgeRouter(walletClient, stargateAdapterAddress, bridgeRouterAddress)
}

/**
 * Update adapter addresses for cross-chain support after all adapters are deployed
 */
export async function updateStargateAdapterAddresses(
  stargateAdapterAddress: Address,
  allNetworkConfigs: Record<string, BaseConfig>,
): Promise<void> {
  console.log(kleur.blue('Updating Stargate adapter cross-chain addresses'))

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions using proper setup
  const walletClient = await getWalletClient()

  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  for (const chainInfo of supportedChains) {
    try {
      const targetNetworkName = getNetworkNameFromChainId(chainInfo.chainId)
      const targetNetworkConfig = allNetworkConfigs[targetNetworkName]
      const targetAdapterAddress =
        targetNetworkConfig?.deployedContracts?.bridge?.adapters?.stargate?.address

      if (targetAdapterAddress) {
        // Check if the current adapter address is correct
        const currentAdapterAddress = (await stargateAdapter.read.chainToAdapter([
          chainInfo.chainId,
        ])) as string

        if (currentAdapterAddress.toLowerCase() !== targetAdapterAddress.toLowerCase()) {
          console.log(
            `Updating adapter address for chain ${chainInfo.chainId} from ${currentAdapterAddress} to ${targetAdapterAddress}`,
          )

          const hash = await writeContractTx(
            walletClient,
            stargateAdapterAddress,
            STARGATE_UPDATE_CHAIN_ADAPTER_ABI,
            'updateChainAdapter',
            [chainInfo.chainId, targetAdapterAddress as Address],
          )

          console.log(
            kleur.green(`Chain ${chainInfo.chainId} adapter address updated, tx: ${hash}`),
          )

          await waitForTransactionConfirmation(hash)
        } else {
          console.log(
            kleur.yellow(`Chain ${chainInfo.chainId} adapter address already correct, skipping`),
          )
        }
      } else {
        console.log(
          kleur.yellow(`No adapter address found for chain ${chainInfo.chainId}, skipping`),
        )
      }
    } catch (error) {
      console.error(
        kleur.red(`Error updating adapter address for chain ${chainInfo.chainId}:`),
        error,
      )
    }
  }
}

/**
 * Optimized Stargate contract validation with caching
 */
export async function validateStargateContract(contractAddress: string): Promise<boolean> {
  try {
    const publicClient = await hre.viem.getPublicClient()

    // First try OFT-style contract (has stargateType function)
    try {
      await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: STARGATE_OFT_ABI,
        functionName: 'stargateType',
      })
      return true
    } catch {
      // Try Pool-style contract (has token function)
      try {
        await publicClient.readContract({
          address: contractAddress as `0x${string}`,
          abi: STARGATE_POOL_ABI,
          functionName: 'token',
        })
        return true
      } catch {
        // Try common Stargate functions
        try {
          await publicClient.readContract({
            address: contractAddress as `0x${string}`,
            abi: STARGATE_COMMON_ABI,
            functionName: 'localDecimals',
          })
          return true
        } catch {
          // Final check: just verify it's a contract
          const code = await publicClient.getBytecode({
            address: contractAddress as `0x${string}`,
          })
          return code !== undefined && code !== '0x'
        }
      }
    }
  } catch {
    return false
  }
}
