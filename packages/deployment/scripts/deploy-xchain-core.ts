import hre from 'hardhat'
import kleur from 'kleur'
import { BaseConfig } from '../types/config-types'
import { deployBridgeContracts } from './bridge/bridge-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { getChainId } from './helpers/get-chainid'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

async function deployBridge() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))
  const useBummerConfig = await promptForConfigType()
  const config = getConfigByNetwork(
    network,
    { common: true, gov: true },
    useBummerConfig,
  ) as BaseConfig
  if (!config) {
    throw new Error(`No configuration found for network ${network}`)
  }

  if (!config.deployedContracts.bridge) {
    throw new Error('Bridge configuration is missing')
  }
  const allConfigs = getConfigByNetwork('all', { common: false }, useBummerConfig) as Record<
    string,
    BaseConfig
  >
  if (!allConfigs) {
    throw new Error('Failed to load all network configurations')
  }

  console.log(kleur.green().bold('Starting bridge deployment...'))

  try {
    const currentChainId = getChainId()
    const deployedBridge = await deployBridgeContracts(config, allConfigs, currentChainId)

    console.log(kleur.green().bold('Bridge deployment completed successfully!'))
    console.log('Deployed contracts:')
    console.log('- BridgeRouter:', deployedBridge.bridgeRouter.address)
    console.log('- CrossChainRegistry:', deployedBridge.crossChainRegistry.address)
    console.log(kleur.blue('Updating configuration with deployed addresses...'))
    await updateIndexJson('bridge', network, deployedBridge, useBummerConfig)

    return deployedBridge
  } catch (error) {
    console.error(kleur.red('Error during bridge deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    throw error
  }
}
if (require.main === module) {
  deployBridge().catch((error) => {
    console.error(kleur.red('Error during bridge deployment:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { deployBridge }
