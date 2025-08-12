import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import {
  configureLayerZeroAdapter,
  configureLayerZeroAdapterPeersWithConfig,
  deployLayerZeroAdapter,
  updateLayerZeroAdapterPeers,
} from './adapters/layerzero'
import {
  configureStargateAdapter,
  deployStargateAdapter,
  updateStargateAdapterAddresses,
} from './adapters/stargate'
import { waitForPendingTransactions } from './adapters/utils'

/**
 * Interface for deployed bridge adapters
 */
export interface DeployedBridgeAdapters {
  layerZero?: { address: Address }
  stargate?: { address: Address }
}

/**
 * Check if an adapter is already registered with the bridge router
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
 * Deploy and configure bridge adapters
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration from general config
 * @param allNetworkConfigs All network configurations for cross-chain setup
 * @param options Optional flags; set performPostDeployGovConfig=true for bummer deployments
 * @returns Deployed bridge adapters
 */
export async function deployBridgeAdapters(
  bridgeRouterAddress: Address,
  networkConfig: any,
  allNetworkConfigs?: Record<string, any>,
  options?: { performPostDeployGovConfig?: boolean },
): Promise<DeployedBridgeAdapters> {
  console.log(kleur.cyan().bold('Starting bridge adapters deployment...'))

  const deployedAdapters: DeployedBridgeAdapters = {}
  // Default to performing post-deploy config for backward compatibility; callers can disable
  const performGovConfig = options?.performPostDeployGovConfig !== false

  // Resolve common addresses from config
  const crossChainRegistryAddress: Address | undefined =
    networkConfig.deployedContracts?.bridge?.crossChainRegistry?.address
  const accessManagerAddress: Address | undefined =
    networkConfig.deployedContracts?.gov?.protocolAccessManager?.address

  if (!crossChainRegistryAddress) {
    throw new Error('crossChainRegistry address missing in network config')
  }
  if (!accessManagerAddress) {
    throw new Error('protocolAccessManager address missing in network config')
  }

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
          crossChainRegistryAddress as Address,
          networkConfig,
          allNetworkConfigs,
        )
        deployedAdapters.layerZero = { address: layerZeroAdapterAddress }
        // Wait for deployment to be confirmed before any post-deploy configuration
        console.log(
          kleur.blue('Waiting for LayerZero adapter deployment transactions to be confirmed...'),
        )
        await waitForPendingTransactions()

        if (performGovConfig) {
          await configureLayerZeroAdapter(
            layerZeroAdapterAddress,
            bridgeRouterAddress,
            networkConfig,
          )
        } else {
          console.log(
            kleur.yellow(
              'Skipping LayerZero post-deploy governor configuration (prod/governance-managed).',
            ),
          )
        }
      } catch (error) {
        console.error(kleur.red('Error deploying LayerZero adapter:'), error)
      }
    }
  } else {
    try {
      const layerZeroAdapterAddress = await deployLayerZeroAdapter(
        crossChainRegistryAddress as Address,
        networkConfig,
        allNetworkConfigs,
      )
      deployedAdapters.layerZero = { address: layerZeroAdapterAddress }
      // Wait for deployment to be confirmed before any post-deploy configuration
      console.log(
        kleur.blue('Waiting for LayerZero adapter deployment transactions to be confirmed...'),
      )
      await waitForPendingTransactions()

      if (performGovConfig) {
        await configureLayerZeroAdapter(layerZeroAdapterAddress, bridgeRouterAddress, networkConfig)
      } else {
        console.log(
          kleur.yellow(
            'Skipping LayerZero post-deploy governor configuration (prod/governance-managed).',
          ),
        )
      }
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
          crossChainRegistryAddress as Address,
          accessManagerAddress as Address,
          networkConfig,
        )
        deployedAdapters.stargate = { address: stargateAdapterAddress }
        // Wait for deployment to be confirmed before any post-deploy configuration
        console.log(
          kleur.blue('Waiting for Stargate adapter deployment transactions to be confirmed...'),
        )
        await waitForPendingTransactions()

        if (performGovConfig) {
          await configureStargateAdapter(
            stargateAdapterAddress,
            bridgeRouterAddress,
            networkConfig,
            allNetworkConfigs,
          )
        } else {
          console.log(
            kleur.yellow(
              'Skipping Stargate post-deploy governor configuration (prod/governance-managed).',
            ),
          )
        }
      } catch (error) {
        console.error(kleur.red('Error deploying Stargate adapter:'), error)
      }
    }
  } else {
    try {
      const stargateAdapterAddress = await deployStargateAdapter(
        crossChainRegistryAddress as Address,
        accessManagerAddress as Address,
        networkConfig,
      )
      deployedAdapters.stargate = { address: stargateAdapterAddress }
      // Wait for deployment to be confirmed before any post-deploy configuration
      console.log(
        kleur.blue('Waiting for Stargate adapter deployment transactions to be confirmed...'),
      )
      await waitForPendingTransactions()

      if (performGovConfig) {
        await configureStargateAdapter(
          stargateAdapterAddress,
          bridgeRouterAddress,
          networkConfig,
          allNetworkConfigs,
        )
      } else {
        console.log(
          kleur.yellow(
            'Skipping Stargate post-deploy governor configuration (prod/governance-managed).',
          ),
        )
      }
    } catch (error) {
      console.error(kleur.red('Error deploying Stargate adapter:'), error)
    }
  }

  console.log(kleur.green().bold('Bridge adapters deployment completed!'))
  return deployedAdapters
}

export {
  configureLayerZeroAdapterPeersWithConfig,
  updateLayerZeroAdapterPeers,
  updateStargateAdapterAddresses,
}
