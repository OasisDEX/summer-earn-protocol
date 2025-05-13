import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { BridgeAdaptersConfig } from '../../types/bridge-types'

/**
 * Interface for deployed bridge adapters
 */
export interface DeployedBridgeAdapters {
  layerZero?: { address: Address }
  stargate?: { address: Address }
}

/**
 * Deploy LayerZero adapter
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
  console.log(kleur.blue('Deploying LayerZero adapter'))

  // Validate required configuration
  if (!config.layerZero?.endpoint) {
    throw new Error('LayerZero endpoint not configured')
  }

  if (!config.layerZero.supportedChains || !config.layerZero.lzEids) {
    throw new Error('LayerZero supported chains or endpoint IDs not configured')
  }

  if (config.layerZero.supportedChains.length !== config.layerZero.lzEids.length) {
    throw new Error('LayerZero supported chains and endpoint IDs must have the same length')
  }

  // Deploy using hardhat-viem
  const layerZeroAdapter = await hre.viem.deployContract('LayerZeroAdapter', [
    config.layerZero.endpoint,
    bridgeRouterAddress,
    config.layerZero.supportedChains,
    config.layerZero.lzEids,
    await hre.viem.getSignerAddress(), // Owner address
  ])

  console.log(kleur.green(`LayerZeroAdapter deployed at: ${layerZeroAdapter.address}`))

  return layerZeroAdapter.address
}

/**
 * Deploy Stargate adapter
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
  console.log(kleur.blue('Deploying Stargate adapter'))

  // Validate required configuration
  if (!config.stargate?.router) {
    throw new Error('Stargate router not configured')
  }

  // Deploy using hardhat-viem
  const stargateAdapter = await hre.viem.deployContract('StargateAdapter', [
    config.stargate.router,
    bridgeRouterAddress,
    await hre.viem.getSignerAddress(), // Owner address
  ])

  console.log(kleur.green(`StargateAdapter deployed at: ${stargateAdapter.address}`))

  return stargateAdapter.address
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
  const stargateAdapter = await hre.viem.getContractAt('StargateAdapter', stargateAdapterAddress)

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
  for (const assetInfo of config.stargate.supportedAssets) {
    console.log(
      `Adding supported asset ${assetInfo.asset} on chain ${assetInfo.chainId} with pool ID ${assetInfo.poolId}`,
    )

    // Check if the asset is already supported to avoid unnecessary transactions
    try {
      const isSupported = await stargateAdapter.read.supportsAsset([
        assetInfo.chainId,
        assetInfo.asset,
      ])
      if (!isSupported) {
        const hash = await stargateAdapter.write.addSupportedAsset([
          assetInfo.chainId,
          assetInfo.asset,
          assetInfo.poolId,
        ])
        console.log(
          kleur.green(
            `Asset ${assetInfo.asset} on chain ${assetInfo.chainId} added successfully, tx: ${hash}`,
          ),
        )
      } else {
        console.log(
          kleur.yellow(
            `Asset ${assetInfo.asset} on chain ${assetInfo.chainId} already supported, skipping`,
          ),
        )
      }
    } catch (error) {
      console.error(
        kleur.red(`Error adding asset ${assetInfo.asset} on chain ${assetInfo.chainId}:`),
        error,
      )
    }
  }
}

/**
 * Configure LayerZero adapter read channel
 * @param layerZeroAdapterAddress Address of the deployed LayerZero adapter
 * @param config Bridge adapter configuration
 */
export async function configureLayerZeroAdapter(
  layerZeroAdapterAddress: Address,
  config: BridgeAdaptersConfig,
): Promise<void> {
  console.log(kleur.blue('Configuring LayerZero adapter'))

  if (!config.layerZero?.readChannelId) {
    console.log(kleur.yellow('No LayerZero read channel ID configured, skipping'))
    return
  }

  // Get adapter contract
  const layerZeroAdapter = await hre.viem.getContractAt('LayerZeroAdapter', layerZeroAdapterAddress)

  // Activate read channel
  console.log(`Activating read channel with ID ${config.layerZero.readChannelId}`)
  try {
    const hash = await layerZeroAdapter.write.activateReadChannel([config.layerZero.readChannelId])
    console.log(kleur.green(`Read channel activated successfully, tx: ${hash}`))
  } catch (error) {
    console.error(kleur.red('Error activating read channel:'), error)
  }

  // Set minimum gas limits if configured
  if (config.layerZero.minGasLimits) {
    for (const [msgType, gasLimit] of Object.entries(config.layerZero.minGasLimits)) {
      console.log(`Setting minimum gas limit for message type ${msgType} to ${gasLimit}`)
      try {
        const hash = await layerZeroAdapter.write.setMinGasLimit([
          Number(msgType),
          BigInt(gasLimit),
        ])
        console.log(
          kleur.green(
            `Minimum gas limit for message type ${msgType} set successfully, tx: ${hash}`,
          ),
        )
      } catch (error) {
        console.error(
          kleur.red(`Error setting minimum gas limit for message type ${msgType}:`),
          error,
        )
      }
    }
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

      // Configure LayerZero adapter
      await configureLayerZeroAdapter(layerZeroAdapterAddress, config)

      // Register the adapter with the BridgeRouter
      const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)
      console.log('Registering LayerZero adapter with BridgeRouter')
      const hash = await bridgeRouter.write.registerAdapter([layerZeroAdapterAddress])
      console.log(kleur.green(`LayerZero adapter registered successfully, tx: ${hash}`))
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

      // Configure Stargate adapter
      await configureStargateAdapter(stargateAdapterAddress, config)

      // Register the adapter with the BridgeRouter
      const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)
      console.log('Registering Stargate adapter with BridgeRouter')
      const hash = await bridgeRouter.write.registerAdapter([stargateAdapterAddress])
      console.log(kleur.green(`Stargate adapter registered successfully, tx: ${hash}`))
    } catch (error) {
      console.error(kleur.red('Error deploying Stargate adapter:'), error)
    }
  }

  console.log(kleur.green().bold('Bridge adapters deployment completed!'))

  return deployedAdapters
}
