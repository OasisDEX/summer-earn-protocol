import hre from 'hardhat'
import kleur from 'kleur'
import { BridgeConfig } from '../types/bridge-types'
import { BaseConfig } from '../types/config-types'
import { deployBridgeContracts } from './bridge/bridge-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

async function deployBridge() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Ask about using bummer config at the beginning
  const useBummerConfig = await promptForConfigType()

  // Load network configuration
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true },
    useBummerConfig,
  ) as BaseConfig

  // Validate required configuration
  if (!config) {
    throw new Error(`No configuration found for network ${network}`)
  }

  if (!config.deployedContracts.bridge) {
    throw new Error('Bridge configuration is missing')
  }

  // Load all network configs for updating other chain configs
  const allConfigs = getConfigByNetwork('all', { common: false }, useBummerConfig) as Record<
    string,
    BaseConfig
  >
  if (!allConfigs) {
    throw new Error('Failed to load all network configurations')
  }

  // Load bridge configuration
  const bridgeConfig = config.bridge as BridgeConfig

  // Check for existing contracts
  if (config.deployedContracts.bridge) {
    const bridgeContracts = config.deployedContracts.bridge
    if (
      bridgeContracts.bridgeRouter?.address &&
      bridgeContracts.bridgeRouter.address !== '0x0000000000000000000000000000000000000000'
    ) {
      throw new Error(
        `BridgeRouter is already deployed at ${bridgeContracts.bridgeRouter.address}. Cannot redeploy.`,
      )
    }
    if (
      bridgeContracts.bridgeQueue?.address &&
      bridgeContracts.bridgeQueue.address !== '0x0000000000000000000000000000000000000000'
    ) {
      throw new Error(
        `BridgeQueue is already deployed at ${bridgeContracts.bridgeQueue.address}. Cannot redeploy.`,
      )
    }
  }

  console.log(kleur.green().bold('Starting bridge deployment...'))

  try {
    // Deploy core bridge contracts
    const deployedBridge = await deployBridgeContracts(bridgeConfig, config, allConfigs)

    console.log(kleur.green().bold('Bridge deployment completed successfully!'))
    console.log('Deployed contracts:')
    console.log('- BridgeRouter:', deployedBridge.bridgeRouter.address)
    console.log('- BridgeQueue:', deployedBridge.bridgeQueue.address)

    // Update the configuration with deployed addresses
    console.log(kleur.blue('Updating configuration with deployed addresses...'))
    await updateIndexJson('bridge', network, deployedBridge, useBummerConfig)

    return deployedBridge
  } catch (error) {
    console.error(kleur.red('Error during bridge deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    throw error
  }
}

// Execute the deployBridge function and handle any errors
if (require.main === module) {
  deployBridge().catch((error) => {
    console.error(kleur.red('Error during bridge deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { deployBridge }
