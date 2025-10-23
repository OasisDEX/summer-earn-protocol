import hre from 'hardhat'
import kleur from 'kleur'
import { getConfigByNetwork } from '../helpers/config-handler'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { getBridgeAdapterConfigs, hasBridgeAdapterConfigs } from './bridge-config-helpers'

/**
 * Script that demonstrates using bridge config helpers to extract and display adapter configurations
 */
async function getBridgeConfigs() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Ask about using bummer config at the beginning
  const useBummerConfig = await promptForConfigType()

  // Load network configuration
  const config = getConfigByNetwork(network, { common: true, gov: true }, useBummerConfig) as any

  // Validate required configuration
  if (!config) {
    throw new Error(`No configuration found for network ${network}`)
  }

  // Check if bridge adapter configs exist
  const hasAdapterConfigs = hasBridgeAdapterConfigs(config)
  if (!hasAdapterConfigs) {
    console.log(kleur.yellow(`No bridge adapter configurations found for network ${network}`))
    return
  }

  // Get bridge adapter configs
  const adapterConfigs = getBridgeAdapterConfigs(config)

  console.log(kleur.green().bold('Bridge adapter configurations:'))

  // Display LayerZero adapter config if exists
  if (adapterConfigs?.layerZero) {
    console.log(kleur.blue('\nLayerZero Adapter Configuration:'))
    console.log(`- Endpoint: ${adapterConfigs.layerZero.endpoint}`)
    console.log(`- Supported Chains: ${adapterConfigs.layerZero.supportedChains.join(', ')}`)
    console.log(`- LZ Endpoint IDs: ${adapterConfigs.layerZero.lzEids.join(', ')}`)
    if (adapterConfigs.layerZero.readChannelId) {
      console.log(`- Read Channel ID: ${adapterConfigs.layerZero.readChannelId}`)
    }
    if (adapterConfigs.layerZero.minGasLimits) {
      console.log('- Minimum Gas Limits:')
      for (const [msgType, gasLimit] of Object.entries(adapterConfigs.layerZero.minGasLimits)) {
        console.log(`  * Message Type ${msgType}: ${gasLimit}`)
      }
    }
  }

  // Display Stargate adapter config if exists
  if (adapterConfigs?.stargate) {
    console.log(kleur.blue('\nStargate Adapter Configuration:'))
    console.log(`- Router: ${adapterConfigs.stargate.router}`)

    if (adapterConfigs.stargate.chainMapping?.length) {
      console.log('- Chain Mappings:')
      for (const mapping of adapterConfigs.stargate.chainMapping) {
        console.log(`  * Chain ${mapping.chainId} => Stargate Chain ${mapping.stargateChainId}`)
      }
    }

    if (adapterConfigs.stargate.supportedAssets?.length) {
      console.log('- Supported Assets:')
      for (const asset of adapterConfigs.stargate.supportedAssets) {
        console.log(`  * Chain ${asset.chainId}, Asset ${asset.asset}, Pool ID ${asset.poolId}`)
      }
    }
  }
}

// Execute the getBridgeConfigs function and handle any errors
if (require.main === module) {
  getBridgeConfigs().catch((error) => {
    console.error(kleur.red('Error retrieving bridge configurations:'))
    console.error(error instanceof Error ? error.message : String(error))
    process.exit(1)
  })
}

export { getBridgeConfigs }
