import hre from 'hardhat'
import kleur from 'kleur'
import { BaseConfig } from '../types/config-types'
import { getBridgeRouterAddress, getChainIdFromConfig } from './lib/config/getters'
import { getConfigByNetwork } from './lib/config/handler'
import { promptForConfigType } from './lib/infrastructure/prompts'

async function updateBridgeRouter() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Ask about using bummer config
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

  const bridgeRouterAddress = getBridgeRouterAddress(config)

  // Load all network configs
  const allConfigs = getConfigByNetwork('all', { common: false }, useBummerConfig) as Record<
    string,
    BaseConfig
  >
  if (!allConfigs) {
    throw new Error('Failed to load all network configurations')
  }

  // Get current chain ID
  const currentChainId = getChainIdFromConfig(config)

  // Get BridgeRouter contract
  const bridgeRouter = await hre.viem.getContractAt('BridgeRouter', bridgeRouterAddress)

  console.log(kleur.green().bold('Starting bridge router update...'))

  try {
    // Update router addresses from other chains
    for (const [network, otherConfig] of Object.entries(allConfigs)) {
      // Skip if no common.chainId
      if (!otherConfig.common?.chainId) continue

      const otherChainId = Number(otherConfig.common.chainId)

      // Skip current chain
      if (otherChainId === currentChainId) continue

      // Get router address from other chain
      let routerAddress = null
      if (otherConfig.deployedContracts?.bridge?.bridgeRouter?.address) {
        routerAddress = otherConfig.deployedContracts.bridge.bridgeRouter.address
      } else if (otherConfig.protocolSpecific?.bridge?.bridgeRouter?.address) {
        routerAddress = otherConfig.protocolSpecific.bridge.bridgeRouter.address
      }

      if (routerAddress && routerAddress !== '0x0000000000000000000000000000000000000000') {
        console.log(kleur.blue(`Updating router for chain ${otherChainId}: ${routerAddress}`))

        // Update the router address
        await bridgeRouter.write.setChainRouterAddress([otherChainId, routerAddress])

        console.log(kleur.green(`Successfully updated router address for chain ${otherChainId}`))
      }
    }

    console.log(kleur.green().bold('Bridge router update completed successfully!'))
  } catch (error) {
    console.error(kleur.red('Error during bridge router update:'))
    console.error(error instanceof Error ? error.message : String(error))
    throw error
  }
}

// Execute the updateBridgeRouter function and handle any errors
if (require.main === module) {
  updateBridgeRouter().catch((error) => {
    console.error(kleur.red('Error during bridge router update:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { updateBridgeRouter }
