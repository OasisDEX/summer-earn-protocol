import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import layerZeroConfig from '../../config/adapters/layerzero.json'
import stargateConfig from '../../config/adapters/stargate.json'
import LayerZeroAdapterModule from '../../ignition/modules/adapters/layerzero'
import StargateAdapterModule from '../../ignition/modules/adapters/stargate'
import { BridgeAdaptersConfig } from '../../types/bridge-types'

/**
 * Interface for deployed bridge adapters
 */
export interface DeployedBridgeAdapters {
  layerZero?: { address: Address }
  stargate?: { address: Address }
}

/**
 * Deploy LayerZero adapter using Ignition module
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param config Bridge adapter configuration
 * @param networkConfig Network configuration
 * @returns Deployed LayerZero adapter address
 */
export async function deployLayerZeroAdapter(
  bridgeRouterAddress: Address,
  networkConfig: any,
): Promise<Address> {
  console.log(kleur.blue('Deploying LayerZero adapter using Ignition module'))

  // Get current chain ID
  const chainId = Number(networkConfig.common.chainId)

  // Use endpoint from specialized config
  const endpoint = layerZeroConfig.endpoints[chainId.toString()]
  if (!endpoint) {
    throw new Error(`LayerZero endpoint not configured for chain ID ${chainId}`)
  }

  // Extract chainIds and lzEids from specialized config
  const chainIds: number[] = []
  const lzEids: number[] = []

  for (const mapping of layerZeroConfig.chainMapping) {
    chainIds.push(mapping.chainId)
    lzEids.push(mapping.lzEid)
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
 * @param config Bridge adapter configuration
 * @param networkConfig Network configuration
 * @returns Deployed Stargate adapter address
 */
export async function deployStargateAdapter(
  bridgeRouterAddress: Address,
  networkConfig: any,
): Promise<Address> {
  console.log(kleur.blue('Deploying Stargate adapter using Ignition module'))

  // Get current chain ID
  const chainId = Number(networkConfig.common.chainId)

  // Use router address from specialized config
  const router = stargateConfig.router[chainId.toString() as keyof typeof stargateConfig.router]
  if (!router) {
    throw new Error(`Stargate router not configured for chain ID ${chainId}`)
  }

  // Get signer address
  const [deployer] = await hre.viem.getWalletClients()
  const signerAddress = deployer.account.address

  // Deploy using Ignition module
  const deploymentResult = await hre.ignition.deploy(StargateAdapterModule, {
    parameters: {
      StargateAdapterModule: {
        bridgeRouter: bridgeRouterAddress,
        stargateRouter: router,
        owner: signerAddress,
      },
    },
  })

  const stargateAdapterAddress = deploymentResult.stargateAdapter.address as Address
  console.log(kleur.green(`StargateAdapter deployed at: ${stargateAdapterAddress}`))

  return stargateAdapterAddress
}

/**
 * Configure supported chains and assets for Stargate adapter
 * @param stargateAdapterAddress Address of the deployed Stargate adapter
 * @param config Bridge adapter configuration
 */
export async function configureStargateAdapter(
  stargateAdapterAddress: Address,
  config: BridgeAdaptersConfig,
): Promise<void> {
  console.log(kleur.blue('Configuring Stargate adapter'))

  // Get adapter contract
  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    stargateAdapterAddress,
  )

  // Add supported chains from specialized config
  for (const chainInfo of stargateConfig.chainMapping) {
    console.log(
      `Adding supported chain ${chainInfo.chainId} with Stargate chain ID ${chainInfo.stargateChainId}`,
    )

    // Check if the chain is already supported to avoid unnecessary transactions
    try {
      const isSupported = await stargateAdapter.read.supportsChain([chainInfo.chainId])
      if (!isSupported) {
        const hash = await stargateAdapter.write.addSupportedChain([
          chainInfo.chainId,
          chainInfo.stargateChainId,
        ])
        console.log(kleur.green(`Chain ${chainInfo.chainId} added successfully, tx: ${hash}`))
      } else {
        console.log(kleur.yellow(`Chain ${chainInfo.chainId} already supported, skipping`))
      }
    } catch (error) {
      console.error(kleur.red(`Error adding chain ${chainInfo.chainId}:`), error)
    }
  }

  // Get current chain ID
  const currentChainId = Number(config.common.chainId).toString()

  // SECOND: Add supported assets from pool-based specialized config
  for (const [poolId, poolInfo] of Object.entries(stargateConfig.pools)) {
    // Only add assets that exist on the current chain
    const localAssetAddress = poolInfo.assets[currentChainId]

    if (localAssetAddress) {
      // For each destination chain
      for (const chainId of Object.keys(poolInfo.assets)) {
        // Skip if it's the current chain
        if (chainId === currentChainId) continue

        console.log(
          `Adding supported asset ${localAssetAddress} for bridging to chain ${chainId} with pool ID ${poolId}`,
        )

        try {
          const isSupported = await stargateAdapter.read.isAssetSupported([
            Number(chainId),
            localAssetAddress,
          ])

          if (!isSupported) {
            const hash = await stargateAdapter.write.addSupportedAsset([
              Number(chainId),
              localAssetAddress,
              Number(poolId),
            ])
            console.log(
              kleur.green(
                `Asset mapping for ${localAssetAddress} to chain ${chainId} added successfully, tx: ${hash}`,
              ),
            )
          } else {
            console.log(kleur.yellow(`Asset mapping already supported, skipping`))
          }
        } catch (error) {
          console.error(kleur.red(`Error adding asset mapping:`, error))
        }
      }
    }
  }

  // Set minimum gas limit if configured
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

  // Register adapter with bridge router
  try {
    const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', config.bridgeRouterAddress)
    await bridgeRouter.write.registerAdapter([stargateAdapterAddress])
    console.log(kleur.green(`Stargate adapter registered with bridge router`))
  } catch (error) {
    console.error(kleur.red('Error registering adapter with bridge router:'), error)
  }
}

/**
 * Configure LayerZero adapter read channel
 * @param layerZeroAdapterAddress Address of the deployed LayerZero adapter
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration
 */
export async function configureLayerZeroAdapter(
  layerZeroAdapterAddress: Address,
  bridgeRouterAddress: Address,
  networkConfig: any,
): Promise<void> {
  console.log(kleur.blue('Configuring LayerZero adapter'))

  const chainId = Number(networkConfig.common.chainId)
  const chainConfig = layerZeroConfig.chainConfig[chainId.toString()]

  if (!chainConfig) {
    console.log(kleur.yellow(`No LayerZero configuration found for chain ${chainId}, skipping`))
    return
  }

  // Get adapter contract
  const layerZeroAdapter = await hre.viem.getContractAt('LayerZeroAdapter', layerZeroAdapterAddress)

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
    // Map string message types to numeric values
    const messageTypeMap: Record<string, number> = {
      stateRead: 2, // STATE_READ constant in LayerZeroAdapter.sol
      generalMessage: 3, // GENERAL_MESSAGE constant in LayerZeroAdapter.sol
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
        const hash = await layerZeroAdapter.write.setMinGasLimit([numMsgType, BigInt(gasLimit)])
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
    const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)
    await bridgeRouter.write.registerAdapter([layerZeroAdapterAddress])
    console.log(kleur.green(`LayerZero adapter registered with bridge router`))
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
    const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)
    return await bridgeRouter.read.isValidAdapter([adapterAddress])
  } catch (error) {
    console.error(kleur.red('Error checking if adapter is registered:'), error)
    return false
  }
}

/**
 * Deploy and configure bridge adapters
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration
 * @returns Deployed bridge adapters
 */
export async function deployBridgeAdapters(
  bridgeRouterAddress: Address,
  networkConfig: any,
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
      // Deploy LayerZero adapter if not registered
      try {
        const layerZeroAdapterAddress = await deployLayerZeroAdapter(
          bridgeRouterAddress,
          networkConfig,
        )
        deployedAdapters.layerZero = { address: layerZeroAdapterAddress }

        // Configure the adapter post-deployment
        await configureLayerZeroAdapter(layerZeroAdapterAddress, bridgeRouterAddress, networkConfig)
      } catch (error) {
        console.error(kleur.red('Error deploying LayerZero adapter:'), error)
      }
    }
  } else {
    // Deploy LayerZero adapter if not in config
    try {
      const layerZeroAdapterAddress = await deployLayerZeroAdapter(
        bridgeRouterAddress,
        networkConfig,
      )
      deployedAdapters.layerZero = { address: layerZeroAdapterAddress }

      // Configure the adapter post-deployment
      await configureLayerZeroAdapter(layerZeroAdapterAddress, bridgeRouterAddress, networkConfig)
    } catch (error) {
      console.error(kleur.red('Error deploying LayerZero adapter:'), error)
    }
  }

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
      // Deploy Stargate adapter if not registered
      try {
        const stargateAdapterAddress = await deployStargateAdapter(
          bridgeRouterAddress,
          networkConfig,
        )
        deployedAdapters.stargate = { address: stargateAdapterAddress }

        // Configure the adapter post-deployment
        const stargateConfig = { bridgeRouterAddress }
        await configureStargateAdapter(stargateAdapterAddress, stargateConfig)
      } catch (error) {
        console.error(kleur.red('Error deploying Stargate adapter:'), error)
      }
    }
  } else {
    // Deploy Stargate adapter if not in config
    try {
      const stargateAdapterAddress = await deployStargateAdapter(bridgeRouterAddress, networkConfig)
      deployedAdapters.stargate = { address: stargateAdapterAddress }

      // Configure the adapter post-deployment
      const stargateConfig = { bridgeRouterAddress }
      await configureStargateAdapter(stargateAdapterAddress, stargateConfig)
    } catch (error) {
      console.error(kleur.red('Error deploying Stargate adapter:'), error)
    }
  }

  console.log(kleur.green().bold('Bridge adapters deployment completed!'))

  return deployedAdapters
}
