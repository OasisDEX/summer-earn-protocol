import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
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
  config: BridgeAdaptersConfig,
  networkConfig: any,
): Promise<Address> {
  console.log(kleur.blue('Deploying LayerZero adapter using Ignition module'))

  // Validate required configuration
  if (!config.layerZero?.endpoint) {
    throw new Error('LayerZero endpoint not configured')
  }

  if (!config.layerZero.supportedChains) {
    throw new Error('LayerZero supported chains not configured')
  }

  // Extract chainIds and lzEids from supportedChains array
  const chainIds: number[] = []
  const lzEids: number[] = []

  for (const item of config.layerZero.supportedChains) {
    chainIds.push(item.chainId)
    lzEids.push(item.lzEid)
  }

  // Get the deployer address using viem
  const [deployer] = await hre.viem.getWalletClients()
  const signerAddress = deployer.account.address

  // Deploy using Ignition module
  const deploymentResult = await hre.ignition.deploy(LayerZeroAdapterModule, {
    parameters: {
      LayerZeroAdapterModule: {
        bridgeRouter: bridgeRouterAddress,
        lzEndpoint: config.layerZero.endpoint,
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
  config: BridgeAdaptersConfig,
  networkConfig: any,
): Promise<Address> {
  console.log(kleur.blue('Deploying Stargate adapter using Ignition module'))

  // Validate required configuration
  if (!config.stargate?.router) {
    throw new Error('Stargate router not configured')
  }

  // Get signer address
  const [deployer] = await hre.viem.getWalletClients()
  const signerAddress = deployer.account.address

  // Deploy using Ignition module
  const deploymentResult = await hre.ignition.deploy(StargateAdapterModule, {
    parameters: {
      StargateAdapterModule: {
        bridgeRouter: bridgeRouterAddress,
        stargateRouter: config.stargate.router,
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

  if (!config.stargate?.chainMapping) {
    throw new Error('Stargate chain mappings not configured')
  }

  if (!config.stargate?.supportedAssets) {
    throw new Error('Stargate supported assets not configured')
  }

  // Get adapter contract
  const stargateAdapter = await hre.viem.getContractAt(
    'StargateAdapter' as string,
    stargateAdapterAddress,
  )

  // Add supported chains
  for (const chainInfo of config.stargate.chainMapping) {
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

  // Add supported assets
  console.log('config.stargate.supportedAssets [debug]', config.stargate.supportedAssets)
  // Iterate through each chain ID
  for (const chainId of Object.keys(config.stargate.supportedAssets)) {
    // Iterate through assets for this chain
    for (const assetInfo of config.stargate.supportedAssets[chainId]) {
      console.log(
        `Adding supported asset ${assetInfo.asset} on chain ${chainId} with pool ID ${assetInfo.poolId}`,
      )

      // Check if the asset is already supported to avoid unnecessary transactions
      try {
        const isSupported = await stargateAdapter.read.supportsAsset([
          Number(chainId), // Convert string chainId to number
          assetInfo.asset,
        ])
        if (!isSupported) {
          const hash = await stargateAdapter.write.addSupportedAsset([
            Number(chainId), // Convert string chainId to number
            assetInfo.asset,
            assetInfo.poolId,
          ])
          console.log(
            kleur.green(
              `Asset ${assetInfo.asset} on chain ${chainId} added successfully, tx: ${hash}`,
            ),
          )
        } else {
          console.log(
            kleur.yellow(
              `Asset ${assetInfo.asset} on chain ${chainId} already supported, skipping`,
            ),
          )
        }
      } catch (error) {
        console.error(
          kleur.red(`Error adding asset ${assetInfo.asset} on chain ${chainId}:`),
          error,
        )
      }
    }
  }

  // Register adapter with bridge router
  try {
    const bridgeRouter = await hre.viem.getContractAt(
      'BridgeRouter' as string,
      config.stargate.router,
    )
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
 * @param config Bridge adapter configuration
 */
export async function configureLayerZeroAdapter(
  layerZeroAdapterAddress: Address,
  bridgeRouterAddress: Address,
  config: BridgeAdaptersConfig,
): Promise<void> {
  console.log(kleur.blue('Configuring LayerZero adapter'))

  if (!config.layerZero) {
    console.log(kleur.yellow('No LayerZero configuration found, skipping'))
    return
  }

  // Get adapter contract
  const layerZeroAdapter = await hre.viem.getContractAt(
    'LayerZeroAdapter' as string,
    layerZeroAdapterAddress,
  )

  // Activate read channel if configured
  if (config.layerZero.readChannelId) {
    console.log(`Activating read channel with ID ${config.layerZero.readChannelId}`)
    try {
      const hash = await layerZeroAdapter.write.activateReadChannel([
        config.layerZero.readChannelId,
      ])
      console.log(kleur.green(`Read channel activated successfully, tx: ${hash}`))
    } catch (error) {
      console.error(kleur.red('Error activating read channel:'), error)
    }
  }

  // Set minimum gas limits if configured
  if (config.layerZero.minGasLimits) {
    // Map string message types to numeric values
    const messageTypeMap: Record<string, number> = {
      stateRead: 2, // STATE_READ constant in LayerZeroAdapter.sol
      generalMessage: 3, // GENERAL_MESSAGE constant in LayerZeroAdapter.sol
    }

    for (const [strMsgType, gasLimit] of Object.entries(config.layerZero.minGasLimits)) {
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
    const bridgeRouter = await hre.viem.getContractAt('BridgeRouter' as string, bridgeRouterAddress)
    await bridgeRouter.write.registerAdapter([layerZeroAdapterAddress])
    console.log(kleur.green(`LayerZero adapter registered with bridge router`))
  } catch (error) {
    console.error(kleur.red('Error registering adapter with bridge router:'), error)
  }
}

/**
 * Deploy and configure bridge adapters
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param config Bridge adapter configuration
 * @param networkConfig Network configuration
 * @returns Deployed bridge adapters
 */
export async function deployBridgeAdapters(
  bridgeRouterAddress: Address,
  config: BridgeAdaptersConfig,
  networkConfig: any,
): Promise<DeployedBridgeAdapters> {
  console.log(kleur.cyan().bold('Starting bridge adapters deployment...'))

  const deployedAdapters: DeployedBridgeAdapters = {}

  // Deploy LayerZero adapter if configured
  if (config.layerZero) {
    try {
      const layerZeroAdapterAddress = await deployLayerZeroAdapter(
        bridgeRouterAddress,
        config,
        networkConfig,
      )
      deployedAdapters.layerZero = { address: layerZeroAdapterAddress }

      // Configure the adapter post-deployment
      await configureLayerZeroAdapter(layerZeroAdapterAddress, bridgeRouterAddress, config)
    } catch (error) {
      console.error(kleur.red('Error deploying LayerZero adapter:'), error)
    }
  }

  // Deploy Stargate adapter if configured
  if (config.stargate) {
    try {
      const stargateAdapterAddress = await deployStargateAdapter(
        bridgeRouterAddress,
        config,
        networkConfig,
      )
      deployedAdapters.stargate = { address: stargateAdapterAddress }

      // Configure the adapter post-deployment
      await configureStargateAdapter(stargateAdapterAddress, config)
    } catch (error) {
      console.error(kleur.red('Error deploying Stargate adapter:'), error)
    }
  }

  console.log(kleur.green().bold('Bridge adapters deployment completed!'))

  return deployedAdapters
}
