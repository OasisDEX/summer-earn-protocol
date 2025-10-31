import kleur from 'kleur'
import { Address } from 'viem'
import { DeployedBridgeAdapters } from '../../types/bridge-types'
import { BaseConfig } from '../../types/config-types'
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
import { isAdapterRegistered, waitForPendingTransactions } from './adapters/utils'

/**
 * Deploy and configure bridge adapters
 * @param bridgeRouterAddress Address of the deployed BridgeRouter
 * @param networkConfig Network configuration from general config
 * @param allNetworkConfigs All network configurations for cross-chain setup
 * @returns Deployed bridge adapters
 */
async function deployBridgeAdapters(
  bridgeRouterAddress: Address,
  networkConfig: BaseConfig,
  allNetworkConfigs?: Record<string, BaseConfig>,
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
        const layerZeroAdapterAddress = await deployLayerZeroAdapter(networkConfig)
        deployedAdapters.layerZero = { address: layerZeroAdapterAddress }
        await configureLayerZeroAdapter(layerZeroAdapterAddress, bridgeRouterAddress, networkConfig)
      } catch (error) {
        console.error(kleur.red('Error deploying LayerZero adapter:'), error)
      }
    }
  } else {
    try {
      const layerZeroAdapterAddress = await deployLayerZeroAdapter(networkConfig, allNetworkConfigs)
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
        const stargateAdapterAddress = await deployStargateAdapter(networkConfig)
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
      const stargateAdapterAddress = await deployStargateAdapter(networkConfig)
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
  DeployedBridgeAdapters,
  configureLayerZeroAdapterPeersWithConfig,
  deployBridgeAdapters,
  updateLayerZeroAdapterPeers,
  updateStargateAdapterAddresses,
}
