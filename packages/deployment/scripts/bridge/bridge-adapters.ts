import kleur from 'kleur'
import { Address, getAddress } from 'viem'
import {
  configureLayerZeroAdapter,
  configureLayerZeroAdapterPeersWithConfig,
  deployLayerZeroAdapter,
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

export {
  configureLayerZeroAdapterPeers,
  configureLayerZeroAdapterPeersWithConfig,
  updateStargateAdapterAddresses,
}
