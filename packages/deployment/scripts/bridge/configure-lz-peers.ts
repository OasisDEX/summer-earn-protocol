import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { getConfigByNetwork } from '../helpers/config-handler'
import { promptForConfigType } from '../helpers/prompt-helpers'
import { configureLayerZeroAdapterPeers } from './bridge-adapters'

/**
 * Script to configure LayerZero adapter peers across all deployed chains
 * This should be run after all chains have deployed their LayerZero adapters
 *
 * Usage:
 * npx hardhat run scripts/bridge/configure-lz-peers.ts --network <network-name>
 */
async function main() {
  console.log(kleur.cyan().bold(`Configuring LayerZero adapter peers on ${hre.network.name}...`))

  // Ask if user wants to use bummer config
  const useBummerConfig = await promptForConfigType()

  console.log(kleur.blue(`Using ${useBummerConfig ? 'bummer' : 'production'} config`))

  // Get current network config - don't validate bridge since it might not exist yet
  const currentNetworkConfig = getConfigByNetwork(
    hre.network.name,
    {
      common: true,
      bridge: false, // Don't validate bridge deployment - we'll check manually
      gov: false,
      core: false,
    },
    useBummerConfig,
  )

  // Check if bridge configuration exists
  if (!currentNetworkConfig.deployedContracts.bridge) {
    throw new Error(
      `Bridge deployment configuration not found for network ${hre.network.name}. Please deploy bridge contracts first.`,
    )
  }

  const layerZeroAdapterAddress =
    currentNetworkConfig.deployedContracts.bridge?.adapters?.layerZero?.address

  if (!layerZeroAdapterAddress) {
    throw new Error(
      `LayerZero adapter not found in config for network ${hre.network.name}. Please deploy LayerZero adapter first.`,
    )
  }

  console.log(kleur.blue(`Found LayerZero adapter at: ${layerZeroAdapterAddress}`))

  // Load all network configurations
  const supportedNetworks = ['mainnet', 'base', 'arbitrum', 'sonic'] // Add more as needed
  const allNetworkConfigs: Record<string, any> = {}

  for (const networkName of supportedNetworks) {
    try {
      const config = getConfigByNetwork(
        networkName,
        {
          common: true,
          bridge: false, // Don't validate bridge - we'll check manually
          gov: false,
          core: false,
        },
        useBummerConfig,
      )

      // Check if this network has a LayerZero adapter deployed
      if (config.deployedContracts.bridge?.adapters?.layerZero?.address) {
        allNetworkConfigs[networkName] = config
        console.log(kleur.green(`✓ Loaded config for ${networkName}`))
      } else {
        console.log(
          kleur.yellow(`⚠ ${networkName} doesn't have LayerZero adapter deployed, skipping`),
        )
      }
    } catch (error) {
      console.log(
        kleur.yellow(`⚠ Could not load config for ${networkName}: ${(error as Error).message}`),
      )
    }
  }

  console.log(
    kleur.blue(`Loaded configurations for ${Object.keys(allNetworkConfigs).length} networks`),
  )

  // Check if we have enough networks for peering
  if (Object.keys(allNetworkConfigs).length < 2) {
    console.log(
      kleur.yellow(
        '⚠ Found less than 2 networks with LayerZero adapters. Peering requires at least 2 networks.',
      ),
    )
    console.log(kleur.blue('This might be expected if you are setting up the first network.'))
    console.log(kleur.green('✅ Script completed (no peering needed with < 2 networks)'))
    return
  }

  // Configure LayerZero adapter peers
  try {
    await configureLayerZeroAdapterPeers(layerZeroAdapterAddress as Address, allNetworkConfigs)

    console.log(
      kleur.green().bold('✅ LayerZero adapter peers configuration completed successfully!'),
    )
  } catch (error) {
    console.error(kleur.red().bold('❌ Failed to configure LayerZero adapter peers:'))
    console.error(error)
    process.exit(1)
  }
}

// Handle script execution
main()
  .then(() => {
    console.log(kleur.green().bold('Script completed successfully'))
    process.exit(0)
  })
  .catch((error) => {
    console.error(kleur.red().bold('Script failed:'))
    console.error(error)
    process.exit(1)
  })
