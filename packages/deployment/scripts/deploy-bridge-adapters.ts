import hre from 'hardhat'
import kleur from 'kleur'
import { Address, isAddressEqual, zeroAddress } from 'viem'
import { BaseConfig } from '../types/config-types'
import {
  configureLayerZeroAdapter,
  configureStargateAdapter,
  deployBridgeAdapters,
} from './bridge/bridge-adapters'
import { getConfigByNetwork } from './helpers/config-handler'
import { promptForConfigType, promptYesNo } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

/**
 * Wait for pending transactions to be confirmed
 * @param requiredConfirmations Number of confirmations required (default: 5)
 * @param checkIntervalMs Time in ms between checks (default: 5000)
 * @param maxAttempts Maximum number of attempts (default: 24, 2 minutes total)
 */
async function waitForPendingTransactions(
  requiredConfirmations = 5,
  checkIntervalMs = 5000,
  maxAttempts = 24,
): Promise<void> {
  const [deployer] = await hre.viem.getWalletClients()
  const provider = await hre.viem.getPublicClient()
  const address = deployer.account.address

  console.log(kleur.yellow(`Checking for pending transactions from ${address}...`))

  let attempts = 0
  while (attempts < maxAttempts) {
    try {
      // Get the current nonce
      const currentNonce = await provider.getTransactionCount({ address })

      // Get the pending nonce
      const pendingNonce = await provider.getTransactionCount({
        address,
        blockTag: 'pending',
      })

      if (currentNonce === pendingNonce) {
        console.log(kleur.green('No pending transactions found, continuing...'))
        return
      }

      console.log(
        kleur.yellow(
          `Waiting for ${pendingNonce - currentNonce} transactions to be confirmed (${attempts + 1}/${maxAttempts})...`,
        ),
      )

      // Wait for the specified interval
      await new Promise((resolve) => setTimeout(resolve, checkIntervalMs))
      attempts++
    } catch (error) {
      console.error(kleur.red('Error checking pending transactions:'), error)
      attempts++
      // Continue anyway, but log the error
    }
  }

  console.log(kleur.yellow('Max wait time reached, proceeding anyway...'))
}

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

    let deployedAdapters: { layerZero?: { address: Address }; stargate?: { address: Address } } = {}

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
      deployedAdapters = await deployBridgeAdapters(bridgeRouterAddress as Address, config)
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
