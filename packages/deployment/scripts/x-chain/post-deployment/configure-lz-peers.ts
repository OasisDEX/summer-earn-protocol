import hre from 'hardhat'
import kleur from 'kleur'
import { promptForConfigType } from '../../lib/infrastructure/prompts'
import { configureLayerZeroAdapterPeersWithConfig } from '../bridge-adapters'

/**
 * Script to configure LayerZero adapter peers across all deployed chains
 * This should be run after all chains have deployed their LayerZero adapters
 *
 * Usage:
 * npx hardhat run scripts/x-chain/post-deployment/configure-lz-peers.ts --network <network-name>
 */
async function main() {
  console.log(kleur.cyan().bold(`Configuring LayerZero adapter peers on ${hre.network.name}...`))

  // Ask if user wants to use bummer config
  const useBummerConfig = await promptForConfigType()

  console.log(kleur.blue(`Using ${useBummerConfig ? 'bummer' : 'production'} config`))

  try {
    // Configure LayerZero adapter peers using the wrapper function
    // This handles all config loading and peer setup internally
    await configureLayerZeroAdapterPeersWithConfig(
      hre.network.name,
      useBummerConfig,
      ['mainnet', 'base', 'arbitrum', 'sonic'], // Add more as needed
    )

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
