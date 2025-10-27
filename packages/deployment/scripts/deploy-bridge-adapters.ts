import hre from 'hardhat'
import kleur from 'kleur'
import { Address, isAddressEqual, zeroAddress } from 'viem'
import { BaseConfig } from '../types/config-types'
import { configureLayerZeroAdapter } from './bridge/adapters/layerzero'
import { configureStargateAdapter } from './bridge/adapters/stargate'
import { waitForPendingTransactions } from './bridge/adapters/utils'
import { DeployedBridgeAdapters, deployBridgeAdapters } from './bridge/bridge-adapters'
import { getConfigByNetwork } from './lib/config/handler'
import { promptForConfigType, promptYesNo } from './lib/infrastructure/prompts'
import { updateIndexJson } from './lib/infrastructure/update-json'

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
  ) as BaseConfig

  // Get all network configs for cross-chain configuration
  const allNetworkConfigs = getConfigByNetwork('all', { common: true }, useBummerConfig) as Record<
    string,
    any
  >

  // Validate required configuration
  if (!config) {
    throw new Error(`No configuration found for network ${network}`)
  }

  if (!config.deployedContracts.bridge?.bridgeRouter) {
    throw new Error('BridgeRouter address is missing in configuration')
  }

  const bridgeRouterAddress = config.deployedContracts.bridge.bridgeRouter.address

  // Check if we want to reconfigure existing adapters
  const hasExistingAdapters =
    config.deployedContracts.bridge?.adapters?.layerZero?.address &&
    !isAddressEqual(
      config.deployedContracts.bridge.adapters.layerZero.address as Address,
      zeroAddress,
    ) &&
    config.deployedContracts.bridge?.adapters?.stargate?.address &&
    !isAddressEqual(
      config.deployedContracts.bridge.adapters.stargate.address as Address,
      zeroAddress,
    )

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
      deployedAdapters = {
        layerZero: config.deployedContracts.bridge?.adapters?.layerZero
          ? {
              address: config.deployedContracts.bridge.adapters.layerZero.address as Address,
            }
          : undefined,
        stargate: config.deployedContracts.bridge?.adapters?.stargate
          ? {
              address: config.deployedContracts.bridge.adapters.stargate.address as Address,
            }
          : undefined,
      }

      // Reconfigure existing adapters
      if (deployedAdapters.layerZero) {
        console.log(kleur.blue('Reconfiguring LayerZero adapter...'))
        await configureLayerZeroAdapter(
          deployedAdapters.layerZero.address as Address,
          bridgeRouterAddress as Address,
          config,
        )
      }

      if (deployedAdapters.stargate) {
        console.log(kleur.blue('Reconfiguring Stargate adapter...'))
        await configureStargateAdapter(
          deployedAdapters.stargate.address as Address,
          bridgeRouterAddress as Address,
          config,
          allNetworkConfigs,
        )
      }

      console.log(kleur.green().bold('Bridge adapters reconfiguration completed successfully!'))
    } else {
      // Deploy and configure adapters
      deployedAdapters = await deployBridgeAdapters(
        bridgeRouterAddress as Address,
        config,
        allNetworkConfigs,
      )
      console.log(kleur.green().bold('Bridge adapters deployment completed successfully!'))
    }

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

    // Wait again before updating JSON to ensure all transactions are confirmed
    await waitForPendingTransactions()

    await updateIndexJson('bridge', network, config.deployedContracts.bridge, useBummerConfig)

    return deployedAdapters
  } catch (error) {
    console.error(kleur.red('Error during bridge adapters deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    throw error
  }
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
