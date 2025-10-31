import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { BaseConfig } from '../types/config-types'
import {
  getBridgeRouterAddress,
  getExistingAdapterAddresses,
  hasLayerZeroAdapter,
  hasStargateAdapter,
  type ExistingAdapterAddresses,
} from './lib/config/getters'
import { getConfigByNetwork } from './lib/config/handler'
import { promptForConfigType, promptYesNo } from './lib/infrastructure/prompts'
import { updateIndexJson } from './lib/infrastructure/update-json'
import { configureLayerZeroAdapter } from './x-chain/adapters/layerzero'
import { configureStargateAdapter } from './x-chain/adapters/stargate'
import { waitForPendingTransactions } from './lib/contracts/transactions'
import { DeployedBridgeAdapters, deployBridgeAdapters } from './x-chain/bridge-adapters'

/**
 * Log deployed adapter addresses
 */
function logDeployedAdapters(deployedAdapters: DeployedBridgeAdapters): void {
  if (deployedAdapters.layerZero) {
    console.log('- LayerZeroAdapter:', deployedAdapters.layerZero.address)
  }

  if (deployedAdapters.stargate) {
    console.log('- StargateAdapter:', deployedAdapters.stargate.address)
  }
}

/**
 * Update bridge configuration with deployed adapters and save to JSON
 */
async function updateBridgeConfigWithAdapters(
  config: BaseConfig,
  deployedAdapters: DeployedBridgeAdapters,
  network: string,
  useBummerConfig: boolean,
): Promise<void> {
  console.log(kleur.blue('Updating configuration with deployed addresses...'))

  // Ensure bridge config exists
  if (!config.deployedContracts.bridge) {
    throw new Error('Bridge configuration is missing')
  }

  // Add adapters to the bridge configuration
  if (!config.deployedContracts.bridge.adapters) {
    config.deployedContracts.bridge.adapters = {}
  }

  if (deployedAdapters.layerZero) {
    config.deployedContracts.bridge.adapters.layerZero = deployedAdapters.layerZero
  }

  if (deployedAdapters.stargate) {
    config.deployedContracts.bridge.adapters.stargate = deployedAdapters.stargate
  }

  // Wait before updating JSON to ensure all transactions are confirmed
  await waitForPendingTransactions()

  await updateIndexJson('bridge', network, config.deployedContracts.bridge, useBummerConfig)
}

/**
 * Reconfigure existing adapters
 */
async function reconfigureExistingAdapters(
  existingAdapters: ExistingAdapterAddresses,
  bridgeRouterAddress: Address,
  config: BaseConfig,
  allNetworkConfigs: Record<string, any>,
): Promise<void> {
  if (existingAdapters.layerZero) {
    console.log(kleur.blue('Reconfiguring LayerZero adapter...'))
    await configureLayerZeroAdapter(existingAdapters.layerZero, bridgeRouterAddress, config)
  }

  if (existingAdapters.stargate) {
    console.log(kleur.blue('Reconfiguring Stargate adapter...'))
    await configureStargateAdapter(
      existingAdapters.stargate,
      bridgeRouterAddress,
      config,
      allNetworkConfigs,
    )
  }
}

async function deployXChainAdapters() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Ask about using bummer config at the beginning
  const useBummerConfig = await promptForConfigType()

  // Load network configuration
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, bridge: true },
    useBummerConfig,
  ) as BaseConfig

  // Validate required configuration early
  if (!config) {
    throw new Error(`No configuration found for network ${network}`)
  }

  // Validate bridge configuration exists early
  if (!config.deployedContracts.bridge) {
    throw new Error('Bridge configuration is missing')
  }

  // Get all network configs for cross-chain configuration
  const allNetworkConfigs = getConfigByNetwork('all', { common: true }, useBummerConfig) as Record<
    string,
    any
  >

  const bridgeRouterAddress = getBridgeRouterAddress(config)

  // Check if we want to reconfigure existing adapters
  const hasExistingAdapters = hasLayerZeroAdapter(config) && hasStargateAdapter(config)

  let reconfigureOnly = false
  if (hasExistingAdapters) {
    reconfigureOnly = await promptYesNo(
      'Existing adapters found. Do you want to reconfigure them without redeploying?',
    )
  }

  console.log(
    kleur
      .green()
      .bold(
        reconfigureOnly
          ? 'Starting bridge adapters reconfiguration...'
          : 'Starting bridge adapters deployment...',
      ),
  )

  try {
    // Wait for any pending transactions to be confirmed before starting deployment
    await waitForPendingTransactions()

    let deployedAdapters: DeployedBridgeAdapters = {}

    if (reconfigureOnly) {
      // Use existing adapter addresses from config
      const existingAdapters = getExistingAdapterAddresses(config)
      deployedAdapters = {
        layerZero: existingAdapters.layerZero ? { address: existingAdapters.layerZero } : undefined,
        stargate: existingAdapters.stargate ? { address: existingAdapters.stargate } : undefined,
      }

      // Reconfigure existing adapters
      await reconfigureExistingAdapters(
        existingAdapters,
        bridgeRouterAddress,
        config,
        allNetworkConfigs,
      )

      console.log(kleur.green().bold('Bridge adapters reconfiguration completed successfully!'))
    } else {
      // Deploy and configure adapters
      deployedAdapters = await deployBridgeAdapters(bridgeRouterAddress, config, allNetworkConfigs)
      console.log(kleur.green().bold('Bridge adapters deployment completed successfully!'))
    }

    // Log deployed adapter addresses
    logDeployedAdapters(deployedAdapters)

    // Update the configuration with deployed addresses
    await updateBridgeConfigWithAdapters(config, deployedAdapters, network, useBummerConfig)

    return deployedAdapters
  } catch (error) {
    console.error(kleur.red('Error during bridge adapters deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    throw error
  }
}

// Execute the deployAdapters function and handle any errors
if (require.main === module) {
  deployXChainAdapters().catch((error) => {
    console.error(kleur.red('Error during x-chain bridge adapters deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { deployAdapters }
