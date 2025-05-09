import hre from 'hardhat'
import kleur from 'kleur'
import { BridgeConfig } from '../types/bridge-types'
import { Config } from '../types/config-types'
import { deployBridgeContracts } from './bridge/bridge-contracts'
import { getConfigByNetwork } from './helpers/config-handler'

async function deployBridge() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Load network configuration
  const config = getConfigByNetwork(network, { common: true }, false)

  // Load all network configs for updating other chain configs
  const allConfigs = getConfigByNetwork('all', { common: false }, false) as Config

  // Load bridge configuration
  const bridgeConfig: BridgeConfig = config.bridge

  console.log(kleur.green().bold('Starting bridge deployment...'))

  // Deploy core bridge contracts
  const deployedBridge = await deployBridgeContracts(bridgeConfig, config, allConfigs)

  console.log(kleur.green().bold('Bridge deployment completed successfully!'))
  console.log('Deployed contracts:')
  console.log('- BridgeRouter:', deployedBridge.bridgeRouter.address)
  console.log('- BridgeQueue:', deployedBridge.bridgeQueue.address)
}

// Execute the deployBridge function and handle any errors
deployBridge().catch((error) => {
  console.error(kleur.red('Error during bridge deployment:'))
  console.error(error instanceof Error ? error.message : String(error))
  process.exit(1)
})
