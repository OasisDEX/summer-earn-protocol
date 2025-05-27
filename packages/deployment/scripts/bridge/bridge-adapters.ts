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

  // Deploy using Ignition module - V2 has simplified constructor
  const deploymentResult = await hre.ignition.deploy(StargateAdapterModule, {
    parameters: {
      StargateAdapterModule: {
        bridgeRouter: bridgeRouterAddress,
        owner: signerAddress,
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

  const currentChainId = Number(networkConfig.common.chainId)
  const supportedChains = getSupportedChainsFromConfig(allNetworkConfigs)

  // Add supported chains (using general config)
  for (const chainInfo of supportedChains) {
    console.log(
      `Adding supported chain ${chainInfo.chainId} with LayerZero endpoint ID ${chainInfo.endpointId}`,
    )

    try {
      const isSupported = await stargateAdapter.read.supportsChain([chainInfo.chainId])
      if (!isSupported) {
        const hash = await stargateAdapter.write.addSupportedChain([
          chainInfo.chainId,
          chainInfo.endpointId,
        ])
        console.log(kleur.green(`Chain ${chainInfo.chainId} added successfully, tx: ${hash}`))

        // Wait for transaction confirmation
        const publicClient = await hre.viem.getPublicClient()
        await publicClient.waitForTransactionReceipt({ hash })
        console.log(kleur.green(`Chain ${chainInfo.chainId} transaction confirmed`))
      } else {
        console.log(kleur.yellow(`Chain ${chainInfo.chainId} already supported, skipping`))
      }
    } catch (error) {
      console.error(kleur.red(`Error adding chain ${chainInfo.chainId}:`), error)
      // Don't continue if chain addition fails
      throw error
    }
  }

  // Add a small delay to ensure all transactions are processed
  await new Promise((resolve) => setTimeout(resolve, 2000))

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

  // Configure supported assets (using general config for token addresses + stargate config for contracts)
  for (const [assetSymbol, stargateContract] of Object.entries(currentChainContracts)) {
    // Get token address from general config
    const localAssetAddress = networkConfig.tokens[assetSymbol]

    if (localAssetAddress && stargateContract) {
      // Ensure addresses are properly checksummed
      const checksummedLocalAddress = getAddress(localAssetAddress)
      const checksummedStargateContract = getAddress(stargateContract as string)

      console.log(
        `Configuring asset ${assetSymbol} (${checksummedLocalAddress}) with Stargate contract ${checksummedStargateContract}`,
      )

      // Validate Stargate contract before adding asset
      try {
        // Test if the contract implements the expected interface
        // Try multiple different contract types to be more flexible
        let isValidStargate = false
        let contractType = 'unknown'

        console.log(`Validating Stargate contract ${checksummedStargateContract}...`)

        // First try OFT-style contract (has stargateType function)
        try {
          const publicClient = await hre.viem.getPublicClient()
          await publicClient.readContract({
            address: checksummedStargateContract,
            abi: IStargateOFTABI,
            functionName: 'stargateType',
          })
          isValidStargate = true
          contractType = 'OFT'
          console.log(
            kleur.green(`✓ Stargate OFT contract ${checksummedStargateContract} is valid`),
          )
        } catch (oftError) {
          console.log(`OFT validation failed: ${(oftError as Error).message}`)

          // If stargateType() fails, try Pool-style contract (has token function)
          try {
            const publicClient = await hre.viem.getPublicClient()
            await publicClient.readContract({
              address: checksummedStargateContract,
              abi: IStargatePoolABI,
              functionName: 'token',
            })
            isValidStargate = true
            contractType = 'Pool'
            console.log(
              kleur.green(`✓ Stargate Pool contract ${checksummedStargateContract} is valid`),
            )
          } catch (poolError) {
            console.log(`Pool validation failed: ${(poolError as Error).message}`)

            // Try common Stargate functions as a fallback
            try {
              const publicClient = await hre.viem.getPublicClient()
              await publicClient.readContract({
                address: checksummedStargateContract,
                abi: IStargateCommonABI,
                functionName: 'localDecimals',
              })
              isValidStargate = true
              contractType = 'Common'
              console.log(
                kleur.green(
                  `✓ Stargate contract ${checksummedStargateContract} has common interface`,
                ),
              )
            } catch (commonError) {
              console.log(`Common interface validation failed: ${(commonError as Error).message}`)

              // Final attempt: just check if it's a contract
              try {
                const publicClient = await hre.viem.getPublicClient()
                const code = await publicClient.getBytecode({
                  address: checksummedStargateContract,
                })
                if (code && code !== '0x') {
                  isValidStargate = true
                  contractType = 'Contract (unverified interface)'
                  console.log(
                    kleur.yellow(
                      `⚠ Contract ${checksummedStargateContract} exists but interface unverified - proceeding anyway`,
                    ),
                  )
                } else {
                  console.error(
                    kleur.red(
                      `Contract ${checksummedStargateContract} has no bytecode - not a valid contract`,
                    ),
                  )
                }
              } catch (bytecodeError) {
                console.error(
                  kleur.red(
                    `Failed to check bytecode for ${checksummedStargateContract}: ${(bytecodeError as Error).message}`,
                  ),
                )
              }
            }
          }
        }

        if (!isValidStargate) {
          console.error(
            kleur.red(
              `Invalid Stargate contract ${checksummedStargateContract}: Failed all validation attempts`,
            ),
          )
          continue // Skip this asset
        }

        console.log(
          kleur.blue(
            `Using Stargate contract ${checksummedStargateContract} as ${contractType} type`,
          ),
        )
      } catch (error) {
        console.error(
          kleur.red(`Error validating Stargate contract ${checksummedStargateContract}:`),
          error,
        )
        continue // Skip this asset
      }

      // Configure asset for each destination chain
      for (const destChain of supportedChains) {
        if (destChain.chainId === currentChainId) continue

        console.log(
          `Adding supported asset ${checksummedLocalAddress} for bridging to chain ${destChain.chainId} using destination Stargate contract ${checksummedStargateContract}`,
        )

        try {
          const isSupported = await stargateAdapter.read.isAssetSupported([
            destChain.chainId,
            checksummedLocalAddress,
          ])

          if (!isSupported) {
            const hash = await stargateAdapter.write.addSupportedAsset([
              destChain.chainId,
              checksummedLocalAddress,
              checksummedStargateContract,
            ])
            console.log(
              kleur.green(
                `Asset mapping for ${checksummedLocalAddress} to chain ${destChain.chainId} added successfully, tx: ${hash}`,
              ),
            )
          } else {
            console.log(kleur.yellow(`Asset mapping already supported, skipping`))
          }
        } catch (error) {
          console.error(kleur.red(`Error adding asset mapping:`), error)

          // Add more specific error checking
          const isChainSupported = await stargateAdapter.read.supportsChain([destChain.chainId])
          console.log(`Chain ${destChain.chainId} supported: ${isChainSupported}`)

          // Check if it's already supported
          const isAssetSupported = await stargateAdapter.read.isAssetSupported([
            destChain.chainId,
            checksummedLocalAddress,
          ])
          console.log(`Asset already supported: ${isAssetSupported}`)
        }
      }
    } else {
      console.log(
        kleur.yellow(
          `Asset ${assetSymbol} not available on current chain ${currentChainId} (address: ${localAssetAddress}), skipping`,
        ),
      )
    }
  }

  // Set minimum gas limit from Stargate config
  try {
    const currentGasLimit = await stargateAdapter.read.minDstGasForCall()
    const configuredGasLimit = BigInt(stargateConfig.minDstGasForCall)

    if (currentGasLimit !== configuredGasLimit) {
      await stargateAdapter.write.setMinDstGasForCall([configuredGasLimit])
      console.log(kleur.green(`Minimum destination gas set to ${configuredGasLimit}`))
    } else {
      console.log(
        kleur.yellow(`Minimum destination gas already set to ${currentGasLimit}, skipping`),
      )
    }
  } catch (error) {
    console.error(kleur.red('Error setting minimum destination gas:'), error)
  }

  // Set default transport mode from Stargate config
  try {
    const defaultUseTaxi = stargateConfig.defaultUseTaxi || false
    await stargateAdapter.write.setDefaultTransportMode([defaultUseTaxi])
    console.log(kleur.green(`Default transport mode set to ${defaultUseTaxi ? 'taxi' : 'bus'}`))
  } catch (error) {
    console.error(kleur.red('Error setting default transport mode:'), error)
  }

  // Register adapter with bridge router
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

    const alreadyRegistered = await bridgeRouter.read.isValidAdapter([
      getAddress(stargateAdapterAddress as `0x${string}`),
    ])

    if (!alreadyRegistered) {
      await bridgeRouter.write.registerAdapter([
        getAddress(stargateAdapterAddress as `0x${string}`),
      ])
      console.log(kleur.green(`Stargate V2 adapter registered with bridge router`))
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
 * Configure LayerZero adapter using general config and adapter-specific config
 * @param layerZeroAdapterAddress Address of the deployed LayerZero adapter
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration from general config
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

  // Get adapter contract
  const layerZeroAdapter = await hre.viem.getContractAt(
    'LayerZeroAdapter' as any,
    getAddress(layerZeroAdapterAddress as `0x${string}`),
  )

  // Activate read channel if configured
  if (chainConfig.readChannelId) {
    console.log(`Activating read channel with ID ${chainConfig.readChannelId}`)
    try {
      const hash = await layerZeroAdapter.write.activateReadChannel([chainConfig.readChannelId])
      console.log(kleur.green(`Read channel activated successfully, tx: ${hash}`))
    } catch (error) {
      console.error(kleur.red('Error activating read channel:'), error)
    }
  }

  // Set minimum gas limits if configured
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

      console.log(
        `Setting minimum gas limit for message type ${strMsgType} (${numMsgType}) to ${gasLimit}`,
      )
      try {
        const hash = await layerZeroAdapter.write.setMinGasLimit([
          numMsgType,
          BigInt(gasLimit as number),
        ])
        console.log(
          kleur.green(
            `Minimum gas limit for message type ${strMsgType} set successfully, tx: ${hash}`,
          ),
        )
      } catch (error) {
        console.error(
          kleur.red(`Error setting minimum gas limit for message type ${strMsgType}:`),
          error,
        )
      }
    }
  }

  // Register adapter with bridge router
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
      'BridgeRouter' as any,
      getAddress(actualAddress as `0x${string}`),
    )

    const alreadyRegistered = await bridgeRouter.read.isValidAdapter([
      getAddress(layerZeroAdapterAddress as `0x${string}`),
    ])

    if (!alreadyRegistered) {
      await bridgeRouter.write.registerAdapter([
        getAddress(layerZeroAdapterAddress as `0x${string}`),
      ])
      console.log(kleur.green(`LayerZero adapter registered with bridge router`))
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

    return (await bridgeRouter.read.isValidAdapter([
      getAddress(adapterAddress as `0x${string}`),
    ])) as boolean
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
