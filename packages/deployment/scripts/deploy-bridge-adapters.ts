import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { deployBridgeAdapters } from './bridge/bridge-adapters'
import { getBridgeAdapterConfigs } from './bridge/bridge-config-helpers'
import { getConfigByNetwork } from './helpers/config-handler'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

async function deployAdapters() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Ask about using bummer config at the beginning
  const useBummerConfig = await promptForConfigType()

  // Load network configuration
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true, bridge: true },
    useBummerConfig,
  ) as any

  // Validate required configuration
  if (!config) {
    throw new Error(`No configuration found for network ${network}`)
  }

  if (!config.deployedContracts.bridge?.bridgeRouter) {
    throw new Error('BridgeRouter address is missing in configuration')
  }

  // Load bridge configuration
  const bridgeConfig = getBridgeAdapterConfigs(config)
  console.log('bridgeConfig [debug]', bridgeConfig)
  if (!bridgeConfig) {
    const continueWithoutConfig = await promptForContinueWithoutConfig()
    if (!continueWithoutConfig) {
      throw new Error('Bridge adapter configuration is missing in network config')
    } else {
      console.log(
        kleur.yellow(
          'Proceeding without bridge adapter configuration. You will need to manually configure adapters later.',
        ),
      )
      // Create empty config
      bridgeConfig = {}
    }
  }

  const bridgeRouterAddress = config.deployedContracts.bridge.bridgeRouter.address

  console.log(kleur.green().bold('Starting bridge adapters deployment...'))

  try {
    // Deploy bridge adapters
    const deployedAdapters = await deployBridgeAdapters(bridgeRouterAddress, bridgeConfig, config)

    console.log(kleur.green().bold('Bridge adapters deployment completed successfully!'))

    if (deployedAdapters.layerZero) {
      console.log('- LayerZeroAdapter:', deployedAdapters.layerZero.address)
    }

    if (deployedAdapters.stargate) {
      console.log('- StargateAdapter:', deployedAdapters.stargate.address)
    }

    // Update the configuration with deployed addresses
    console.log(kleur.blue('Updating configuration with deployed addresses...'))

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

    await updateIndexJson('bridge', network, config.deployedContracts.bridge, useBummerConfig)

    return deployedAdapters
  } catch (error) {
    console.error(kleur.red('Error during bridge adapters deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    throw error
  }
}

/**
 * Prompt the user to continue deployment without bridge adapter configuration
 */
async function promptForContinueWithoutConfig(): Promise<boolean> {
  const response = await prompts({
    type: 'confirm',
    name: 'continue',
    message:
      'No bridge adapter configuration found. Continue without it? (Adapters will need manual configuration later)',
    initial: false,
  })

  return response.continue
}

// Execute the deployAdapters function and handle any errors
if (require.main === module) {
  deployAdapters().catch((error) => {
    console.error(kleur.red('Error during bridge adapters deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { deployAdapters }
