import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import layerZeroConfig from '../../config/adapters/layerzero.json'
import stargateConfig from '../../config/adapters/stargate.json'
import LayerZeroAdapterModule from '../../ignition/modules/adapters/layerzero'
import StargateAdapterModule from '../../ignition/modules/adapters/stargate'
import { isTenderlyVirtualTestnet } from '../helpers/tenderly-helpers'

// Simple ABI for IStargatePool interface validation
const IStargatePoolABI = [
  {
    inputs: [],
    name: 'token',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

// Simple ABI for IStargate OFT interface validation
const IStargateOFTABI = [
  {
    inputs: [],
    name: 'stargateType',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

// Additional ABI for other potential Stargate contract types
const IStargateCommonABI = [
  {
    inputs: [],
    name: 'localDecimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'sharedDecimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

/**
 * Interface for deployed bridge adapters
 */
export interface DeployedBridgeAdapters {
  layerZero?: { address: Address }
  stargate?: { address: Address }
}

// Add a cache for validated contracts to avoid re-validation
const validatedContracts = new Set<string>()

/**
 * Helper function to get all supported chains from general config
 * @param allNetworkConfigs All network configurations
 * @returns Array of supported chains with their LayerZero endpoint IDs
 */
function getSupportedChainsFromConfig(
  allNetworkConfigs?: Record<string, any>,
): Array<{ chainId: number; endpointId: number }> {
  if (!allNetworkConfigs) {
    // Fallback to hardcoded if no configs provided
    return [
      { chainId: 1, endpointId: 30101 },
      { chainId: 8453, endpointId: 30184 },
      { chainId: 42161, endpointId: 30110 },
      { chainId: 146, endpointId: 30332 },
    ]
  }

  // Extract from general config
  const chains: Array<{ chainId: number; endpointId: number }> = []
  for (const [networkName, config] of Object.entries(allNetworkConfigs)) {
    if (config?.common?.chainId && config?.common?.layerZero?.eID) {
      chains.push({
        chainId: Number(config.common.chainId),
        endpointId: Number(config.common.layerZero.eID),
      })
    }
  }

  return chains
}

/**
 * Deploy LayerZero adapter using Ignition module
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration from general config
 * @param allNetworkConfigs All network configurations for cross-chain setup
 * @returns Deployed LayerZero adapter address
 */
export async function deployLayerZeroAdapter(
  bridgeRouterAddress: Address,
  networkConfig: any,
  allNetworkConfigs?: Record<string, any>,
): Promise<Address> {
  console.log(kleur.blue('Deploying LayerZero adapter using Ignition module'))

  // Get current chain ID
  const chainId = Number(networkConfig.common.chainId)

  // Use endpoint from general config
  const endpoint = networkConfig.common.layerZero.lzEndpoint
  if (!endpoint) {
    throw new Error(`LayerZero endpoint not configured for chain ID ${chainId}`)
  }

  // Build chain mapping from general config
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)
  const chainIds: number[] = []
  const lzEids: number[] = []

  for (const chain of supportedChains) {
    chainIds.push(chain.chainId)
    lzEids.push(chain.endpointId)
  }

  // Get the deployer address
  const [deployer] = await hre.viem.getWalletClients()
  const signerAddress = deployer.account.address

  // Deploy using Ignition module
  const deploymentResult = await hre.ignition.deploy(LayerZeroAdapterModule, {
    parameters: {
      LayerZeroAdapterModule: {
        bridgeRouter: bridgeRouterAddress,
        lzEndpoint: endpoint,
        chainIds,
        lzEids,
        owner: signerAddress,
      },
    },
  })

  const layerZeroAdapterAddress = deploymentResult.layerZeroAdapter.address as Address
  console.log(kleur.green(`LayerZeroAdapter deployed at: ${layerZeroAdapterAddress}`))

  return layerZeroAdapterAddress
}

/**
 * Deploy Stargate adapter using Ignition module
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration
 * @returns Deployed Stargate adapter address
 */
export async function deployStargateAdapter(
  bridgeRouterAddress: Address,
  networkConfig: any,
): Promise<Address> {
  console.log(kleur.blue('Deploying Stargate V2 adapter using Ignition module'))

  // Get signer address
  const [deployer] = await hre.viem.getWalletClients()
  const signerAddress = deployer.account.address

  // Get LayerZero endpoint from network config
  const lzEndpoint = networkConfig.common.layerZero.lzEndpoint
  if (!lzEndpoint) {
    throw new Error(
      `LayerZero endpoint not configured for chain ID ${networkConfig.common.chainId}`,
    )
  }

  // Deploy using Ignition module - V2 requires all 3 constructor parameters
  const deploymentResult = await hre.ignition.deploy(StargateAdapterModule, {
    parameters: {
      StargateAdapterModule: {
        bridgeRouter: bridgeRouterAddress,
        owner: signerAddress,
        lzEndpoint: lzEndpoint,
      },
    },
  })

  const stargateAdapterAddress = deploymentResult.stargateAdapter.address as Address
  console.log(kleur.green(`StargateAdapter V2 deployed at: ${stargateAdapterAddress}`))

  return stargateAdapterAddress
}

/**
 * Configure supported chains and assets for Stargate V2 adapter
 * @param stargateAdapterAddress Address of the deployed Stargate adapter
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration from general config
 * @param allNetworkConfigs All network configurations for cross-chain setup
 */
export async function configureStargateAdapter(
  stargateAdapterAddress: Address,
  bridgeRouterAddress: Address,
  networkConfig: any,
  allNetworkConfigs?: Record<string, any>,
): Promise<void> {
  console.log(kleur.blue('Configuring Stargate V2 adapter'))

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions
  const [walletClient] = await hre.viem.getWalletClients()

  const currentChainId = Number(networkConfig.common.chainId)
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  // Debug logging
  console.log(
    'allNetworkConfigs keys:',
    allNetworkConfigs ? Object.keys(allNetworkConfigs) : 'undefined',
  )
  console.log('supportedChains:', supportedChains)

  // Add supported chains (using general config)
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
        // If the call fails, it means the chain is not supported yet (which is expected)
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
          // For current chain, use the current adapter address
          adapterAddress = stargateAdapterAddress
        } else {
          // For other chains, check if we have the adapter address in config
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
            // Skip this chain for now - will be added when that chain's adapter is deployed
            console.log(`No adapter address found for chain ${chainInfo.chainId}, skipping for now`)
            continue
          }
        }

        // Use wallet client directly instead of .write
        const hash = await walletClient.writeContract({
          address: getAddress(stargateAdapterAddress as `0x${string}`),
          abi: [
            {
              inputs: [
                { internalType: 'uint16', name: 'chainId', type: 'uint16' },
                { internalType: 'uint32', name: 'endpointId', type: 'uint32' },
                { internalType: 'address', name: 'adapterAddress', type: 'address' },
              ],
              name: 'addSupportedChain',
              outputs: [],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ] as const,
          functionName: 'addSupportedChain',
          args: [chainInfo.chainId, chainInfo.endpointId, adapterAddress],
        })
        console.log(kleur.green(`Chain ${chainInfo.chainId} added successfully, tx: ${hash}`))

        // Wait for transaction confirmation
        const publicClient = await hre.viem.getPublicClient()
        await publicClient.waitForTransactionReceipt({ hash })
        console.log(kleur.green(`Chain ${chainInfo.chainId} transaction confirmed`))
        chainsAdded++
      } else {
        console.log(kleur.yellow(`Chain ${chainInfo.chainId} already supported, skipping`))
      }
    } catch (error) {
      console.error(kleur.red(`Error adding chain ${chainInfo.chainId}:`), error)
    }
  }

  console.log(kleur.green(`Added ${chainsAdded} new supported chains`))

  // Only add delay if we actually added chains
  if (chainsAdded > 0) {
    console.log(kleur.blue(`Added ${chainsAdded} new chains, waiting for settlement...`))
    await new Promise((resolve) => setTimeout(resolve, 2000))
  }

  // Get Stargate contracts for current chain
  const currentChainContracts = (stargateConfig.contracts as any)[currentChainId.toString()]
  if (!currentChainContracts) {
    console.log(
      kleur.yellow(
        `No Stargate V2 contracts found for current chain ${currentChainId}, skipping asset configuration`,
      ),
    )
    return
  }

  // Configure supported assets
  let assetsConfigured = 0
  for (const [assetSymbol, stargateContract] of Object.entries(currentChainContracts)) {
    // Get token address from general config
    const localAssetAddress = networkConfig.tokens[assetSymbol === 'eth' ? 'weth' : assetSymbol]

    if (localAssetAddress && stargateContract) {
      // Ensure addresses are properly checksummed
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
            continue // Skip this asset
          }
          validatedContracts.add(contractKey)
          console.log(kleur.green(`✓ Stargate contract ${checksummedStargateContract} validated`))
        } catch (error) {
          console.error(
            kleur.red(`Error validating Stargate contract ${checksummedStargateContract}:`),
            error,
          )
          continue // Skip this asset
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
          // Use wallet client directly instead of .write
          const hash = await walletClient.writeContract({
            address: getAddress(stargateAdapterAddress as `0x${string}`),
            abi: [
              {
                inputs: [
                  { internalType: 'address', name: 'asset', type: 'address' },
                  { internalType: 'address', name: 'stargateContract', type: 'address' },
                ],
                name: 'addSupportedAsset',
                outputs: [],
                stateMutability: 'nonpayable',
                type: 'function',
              },
            ] as const,
            functionName: 'addSupportedAsset',
            args: [checksummedLocalAddress, checksummedStargateContract],
          })
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

  console.log(kleur.blue(`Configured ${assetsConfigured} asset mappings`))

  // Set minimum gas limit from Stargate config (with check)
  try {
    const currentGasLimit = BigInt(String(await stargateAdapter.read.minDstGasForCall()))
    const configuredGasLimit = BigInt(stargateConfig.minDstGasForCall)

    if (currentGasLimit !== configuredGasLimit) {
      // Use wallet client directly instead of .write
      const hash = await walletClient.writeContract({
        address: getAddress(stargateAdapterAddress as `0x${string}`),
        abi: [
          {
            inputs: [{ internalType: 'uint256', name: 'gasLimit', type: 'uint256' }],
            name: 'setMinDstGasForCall',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'setMinDstGasForCall',
        args: [configuredGasLimit],
      })
      console.log(
        kleur.green(`Minimum destination gas updated to ${configuredGasLimit}, tx: ${hash}`),
      )
    } else {
      console.log(
        kleur.yellow(`Minimum destination gas already set to ${currentGasLimit}, skipping`),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error setting minimum destination gas:'), error)
  }

  // Set default transport mode from Stargate config (with check)
  try {
    const defaultUseTaxi = stargateConfig.defaultUseTaxi || false
    const currentUseTaxi = Boolean(await stargateAdapter.read.defaultUseTaxi())

    if (currentUseTaxi !== defaultUseTaxi) {
      // Use wallet client directly instead of .write
      const hash = await walletClient.writeContract({
        address: getAddress(stargateAdapterAddress as `0x${string}`),
        abi: [
          {
            inputs: [{ internalType: 'bool', name: 'useTaxi', type: 'bool' }],
            name: 'setDefaultTransportMode',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'setDefaultTransportMode',
        args: [defaultUseTaxi],
      })
      console.log(
        kleur.green(
          `Default transport mode updated to ${defaultUseTaxi ? 'taxi' : 'bus'}, tx: ${hash}`,
        ),
      )
    } else {
      console.log(
        kleur.yellow(
          `Default transport mode already set to ${defaultUseTaxi ? 'taxi' : 'bus'}, skipping`,
        ),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error setting default transport mode:'), error)
  }

  // Register adapter with bridge router (existing check is good)
  try {
    let actualAddress: string
    if (typeof bridgeRouterAddress === 'object' && bridgeRouterAddress !== null) {
      const addressObj = bridgeRouterAddress as any
      actualAddress = addressObj.bridgeRouterAddress || String(bridgeRouterAddress)
    } else {
      actualAddress = String(bridgeRouterAddress)
    }

    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as string,
      getAddress(actualAddress as `0x${string}`),
    )

    const alreadyRegistered = Boolean(
      await bridgeRouter.read.isValidAdapter([getAddress(stargateAdapterAddress as `0x${string}`)]),
    )

    if (!alreadyRegistered) {
      // Use wallet client directly instead of .write
      const hash = await walletClient.writeContract({
        address: getAddress(actualAddress as `0x${string}`),
        abi: [
          {
            inputs: [{ internalType: 'address', name: 'adapter', type: 'address' }],
            name: 'registerAdapter',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'registerAdapter',
        args: [getAddress(stargateAdapterAddress as `0x${string}`)],
      })
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
 * Optimized Stargate contract validation with caching
 */
async function validateStargateContract(contractAddress: string): Promise<boolean> {
  try {
    const publicClient = await hre.viem.getPublicClient()

    // First try OFT-style contract (has stargateType function)
    try {
      await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: IStargateOFTABI,
        functionName: 'stargateType',
      })
      return true
    } catch {
      // Try Pool-style contract (has token function)
      try {
        await publicClient.readContract({
          address: contractAddress as `0x${string}`,
          abi: IStargatePoolABI,
          functionName: 'token',
        })
        return true
      } catch {
        // Try common Stargate functions
        try {
          await publicClient.readContract({
            address: contractAddress as `0x${string}`,
            abi: IStargateCommonABI,
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

/**
 * Configure LayerZero adapter with improved checks
 */
export async function configureLayerZeroAdapter(
  layerZeroAdapterAddress: Address,
  bridgeRouterAddress: Address,
  networkConfig: any,
): Promise<void> {
  console.log(kleur.blue('Configuring LayerZero adapter'))

  const chainId = Number(networkConfig.common.chainId)
  const chainConfig = (layerZeroConfig.chainConfig as any)[chainId.toString()]

  if (!chainConfig) {
    console.log(kleur.yellow(`No LayerZero configuration found for chain ${chainId}, skipping`))
    return
  }

  const layerZeroAdapter = await hre.viem.getContractAt(
    'LayerZeroAdapter' as any,
    getAddress(layerZeroAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions
  const [walletClient] = await hre.viem.getWalletClients()

  // Activate read channel if configured (with check)
  if (chainConfig.readChannelId) {
    try {
      // Check if channel is already active by checking if readChannelId is set
      const currentReadChannelId = BigInt(String(await layerZeroAdapter.read.readChannelId()))

      if (currentReadChannelId !== BigInt(chainConfig.readChannelId)) {
        console.log(`Activating read channel with ID ${chainConfig.readChannelId}`)
        // Use wallet client directly instead of .write
        const hash = await walletClient.writeContract({
          address: getAddress(layerZeroAdapterAddress as `0x${string}`),
          abi: [
            {
              inputs: [{ internalType: 'uint32', name: 'channelId', type: 'uint32' }],
              name: 'activateReadChannel',
              outputs: [],
              stateMutability: 'nonpayable',
              type: 'function',
            },
          ] as const,
          functionName: 'activateReadChannel',
          args: [chainConfig.readChannelId],
        })
        console.log(kleur.green(`Read channel activated successfully, tx: ${hash}`))
      } else {
        console.log(
          kleur.yellow(`Read channel ${chainConfig.readChannelId} already active, skipping`),
        )
      }
    } catch (error) {
      console.error(kleur.red('Error activating read channel:'), error)
    }
  }

  // Set minimum gas limits if configured (with checks)
  if (chainConfig.minGasLimits) {
    const messageTypeMap: Record<string, number> = {
      stateRead: 2,
      generalMessage: 3,
    }

    for (const [strMsgType, gasLimit] of Object.entries(chainConfig.minGasLimits)) {
      const numMsgType = messageTypeMap[strMsgType]
      if (numMsgType === undefined) {
        console.error(kleur.red(`Unknown message type: ${strMsgType}, skipping`))
        continue
      }

      try {
        // Check current gas limit using the minGasLimits mapping
        const currentGasLimit = BigInt(
          String(await layerZeroAdapter.read.minGasLimits([numMsgType])),
        )
        const configuredGasLimit = BigInt(gasLimit as number)

        if (currentGasLimit !== configuredGasLimit) {
          console.log(
            `Setting minimum gas limit for message type ${strMsgType} (${numMsgType}) to ${gasLimit}`,
          )
          // Use wallet client directly instead of .write
          const hash = await walletClient.writeContract({
            address: getAddress(layerZeroAdapterAddress as `0x${string}`),
            abi: [
              {
                inputs: [
                  { internalType: 'uint8', name: 'messageType', type: 'uint8' },
                  { internalType: 'uint256', name: 'gasLimit', type: 'uint256' },
                ],
                name: 'setMinGasLimit',
                outputs: [],
                stateMutability: 'nonpayable',
                type: 'function',
              },
            ] as const,
            functionName: 'setMinGasLimit',
            args: [numMsgType, configuredGasLimit],
          })
          console.log(
            kleur.green(
              `Minimum gas limit for message type ${strMsgType} updated successfully, tx: ${hash}`,
            ),
          )
        } else {
          console.log(
            kleur.yellow(
              `Minimum gas limit for message type ${strMsgType} already set to ${currentGasLimit}, skipping`,
            ),
          )
        }
      } catch (error) {
        console.error(
          kleur.red(`Error setting minimum gas limit for message type ${strMsgType}:`),
          error,
        )
      }
    }
  }

  // Register adapter with bridge router (existing check is good)
  try {
    let actualAddress: string
    if (typeof bridgeRouterAddress === 'object' && bridgeRouterAddress !== null) {
      const addressObj = bridgeRouterAddress as any
      actualAddress = addressObj.bridgeRouterAddress || String(bridgeRouterAddress)
    } else {
      actualAddress = String(bridgeRouterAddress)
    }

    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as any,
      getAddress(actualAddress as `0x${string}`),
    )

    const alreadyRegistered = Boolean(
      await bridgeRouter.read.isValidAdapter([
        getAddress(layerZeroAdapterAddress as `0x${string}`),
      ]),
    )

    if (!alreadyRegistered) {
      // Use wallet client directly instead of .write
      const hash = await walletClient.writeContract({
        address: getAddress(actualAddress as `0x${string}`),
        abi: [
          {
            inputs: [{ internalType: 'address', name: 'adapter', type: 'address' }],
            name: 'registerAdapter',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ] as const,
        functionName: 'registerAdapter',
        args: [getAddress(layerZeroAdapterAddress as `0x${string}`)],
      })
      console.log(kleur.green(`LayerZero adapter registered with bridge router, tx: ${hash}`))
    } else {
      console.log(
        kleur.yellow(
          `LayerZero adapter already registered with bridge router, skipping registration`,
        ),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error registering adapter with bridge router:'), error)
  }
}

/**
 * Check if an adapter is already registered with the bridge router
 * @param bridgeRouterAddress Address of the bridge router
 * @param adapterAddress Address of the adapter to check
 * @returns True if the adapter is already registered
 */
async function isAdapterRegistered(
  bridgeRouterAddress: Address,
  adapterAddress: Address,
): Promise<boolean> {
  try {
    // Handle case where bridgeRouterAddress might be an object
    let actualAddress: string
    if (typeof bridgeRouterAddress === 'object' && bridgeRouterAddress !== null) {
      const addressObj = bridgeRouterAddress as any
      actualAddress = addressObj.bridgeRouterAddress || String(bridgeRouterAddress)
    } else {
      actualAddress = String(bridgeRouterAddress)
    }

    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as string,
      getAddress(actualAddress as `0x${string}`),
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
 * @param requiredConfirmations Number of confirmations required (default: 5)
 * @param checkIntervalMs Time in ms between checks (default: 5000)
 * @param maxAttempts Maximum number of attempts (default: 24, 2 minutes total)
 */
async function waitForPendingTransactions(
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

/**
 * Deploy and configure bridge adapters
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration from general config
 * @param allNetworkConfigs All network configurations for cross-chain setup
 * @returns Deployed bridge adapters
 */
export async function deployBridgeAdapters(
  bridgeRouterAddress: Address,
  networkConfig: any,
  allNetworkConfigs?: Record<string, any>,
): Promise<DeployedBridgeAdapters> {
  console.log(kleur.cyan().bold('Starting bridge adapters deployment...'))

  const deployedAdapters: DeployedBridgeAdapters = {}

  // Check if LayerZero adapter is already registered
  const existingLayerZeroAddress =
    networkConfig.deployedContracts.bridge?.adapters?.layerZero?.address
  if (existingLayerZeroAddress) {
    const isRegistered = await isAdapterRegistered(
      bridgeRouterAddress,
      existingLayerZeroAddress as Address,
    )
    if (isRegistered) {
      console.log(kleur.yellow('LayerZero adapter already registered, skipping deployment'))
      deployedAdapters.layerZero = { address: existingLayerZeroAddress as Address }
    } else {
      try {
        const layerZeroAdapterAddress = await deployLayerZeroAdapter(
          bridgeRouterAddress,
          networkConfig,
          allNetworkConfigs,
        )
        deployedAdapters.layerZero = { address: layerZeroAdapterAddress }
        await configureLayerZeroAdapter(layerZeroAdapterAddress, bridgeRouterAddress, networkConfig)
      } catch (error) {
        console.error(kleur.red('Error deploying LayerZero adapter:'), error)
      }
    }
  } else {
    try {
      const layerZeroAdapterAddress = await deployLayerZeroAdapter(
        bridgeRouterAddress,
        networkConfig,
        allNetworkConfigs,
      )
      deployedAdapters.layerZero = { address: layerZeroAdapterAddress }
      await configureLayerZeroAdapter(layerZeroAdapterAddress, bridgeRouterAddress, networkConfig)
    } catch (error) {
      console.error(kleur.red('Error deploying LayerZero adapter:'), error)
    }
  }

  // Wait for LayerZero adapter transactions to be confirmed
  console.log(kleur.blue('Waiting for LayerZero adapter transactions to be confirmed...'))
  await waitForPendingTransactions()

  // Check if Stargate adapter is already registered
  const existingStargateAddress =
    networkConfig.deployedContracts.bridge?.adapters?.stargate?.address
  if (existingStargateAddress) {
    const isRegistered = await isAdapterRegistered(
      bridgeRouterAddress,
      existingStargateAddress as Address,
    )
    if (isRegistered) {
      console.log(kleur.yellow('Stargate adapter already registered, skipping deployment'))
      deployedAdapters.stargate = { address: existingStargateAddress as Address }
    } else {
      try {
        const stargateAdapterAddress = await deployStargateAdapter(
          bridgeRouterAddress,
          networkConfig,
        )
        deployedAdapters.stargate = { address: stargateAdapterAddress }
        await configureStargateAdapter(
          stargateAdapterAddress,
          bridgeRouterAddress,
          networkConfig,
          allNetworkConfigs,
        )
      } catch (error) {
        console.error(kleur.red('Error deploying Stargate adapter:'), error)
      }
    }
  } else {
    try {
      const stargateAdapterAddress = await deployStargateAdapter(bridgeRouterAddress, networkConfig)
      deployedAdapters.stargate = { address: stargateAdapterAddress }
      await configureStargateAdapter(
        stargateAdapterAddress,
        bridgeRouterAddress,
        networkConfig,
        allNetworkConfigs,
      )
    } catch (error) {
      console.error(kleur.red('Error deploying Stargate adapter:'), error)
    }
  }

  console.log(kleur.green().bold('Bridge adapters deployment completed!'))
  return deployedAdapters
}

/**
 * Helper function to get network name from chain ID
 * @param chainId Chain ID
 * @returns Network name used in config
 */
function getNetworkNameFromChainId(chainId: number): string {
  const chainIdToNetworkName: Record<number, string> = {
    1: 'mainnet',
    8453: 'base',
    42161: 'arbitrum',
    146: 'sonic',
  }

  return chainIdToNetworkName[chainId] || `chain-${chainId}`
}

/**
 * Update adapter addresses for cross-chain support after all adapters are deployed
 * @param stargateAdapterAddress Address of the Stargate adapter to update
 * @param allNetworkConfigs All network configurations with deployed adapter addresses
 */
export async function updateStargateAdapterAddresses(
  stargateAdapterAddress: Address,
  allNetworkConfigs: Record<string, any>,
): Promise<void> {
  console.log(kleur.blue('Updating Stargate adapter cross-chain addresses'))

  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    getAddress(stargateAdapterAddress as `0x${string}`),
  )

  // Get wallet client for transactions
  const [walletClient] = await hre.viem.getWalletClients()

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

          // Use wallet client directly instead of .write
          const hash = await walletClient.writeContract({
            address: getAddress(stargateAdapterAddress as `0x${string}`),
            abi: [
              {
                inputs: [
                  { internalType: 'uint16', name: 'chainId', type: 'uint16' },
                  { internalType: 'address', name: 'adapterAddress', type: 'address' },
                ],
                name: 'updateChainAdapter',
                outputs: [],
                stateMutability: 'nonpayable',
                type: 'function',
              },
            ] as const,
            functionName: 'updateChainAdapter',
            args: [chainInfo.chainId, targetAdapterAddress as Address],
          })

          console.log(
            kleur.green(`Chain ${chainInfo.chainId} adapter address updated, tx: ${hash}`),
          )

          // Wait for transaction confirmation
          const publicClient = await hre.viem.getPublicClient()
          await publicClient.waitForTransactionReceipt({ hash })
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
