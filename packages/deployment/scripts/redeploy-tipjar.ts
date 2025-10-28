import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { TipJarContracts, createTipJarModule } from '../ignition/modules/tipjar'
import { BaseConfig } from '../types/config-types'
import {
  getAccessManagerAddress,
  getConfigurationManagerAddress,
  getSummerTokenAddress,
} from './lib/config/getters'
import { getConfigByNetwork } from './lib/config/handler'
import { handleDeploymentId } from './lib/infrastructure/deployment-id-handler'
import { getChainId } from './lib/infrastructure/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './lib/infrastructure/prompts'
import { warnIfTenderlyVirtualTestnet } from './lib/infrastructure/tenderly'
import { updateIndexJson } from './lib/infrastructure/update-json'

/**
 * Deploys the TipJar contract and updates the ConfigurationManager.
 */
async function redeployTipJar() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  // Check if using Tenderly virtual testnet
  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Deployments on Tenderly virtual testnets are temporary and will be lost when the session ends.',
  )

  if (isTenderly) {
    const response = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Do you want to continue with deployment on this Tenderly virtual testnet?',
      initial: false,
    })

    if (!response.continue) {
      console.log(kleur.red('Deployment cancelled.'))
      return
    }
  }

  // Ask about using bummer config
  const useBummerConfig = await promptForConfigType()

  // Load the configuration for the current network
  const config = getConfigByNetwork(
    network,
    { common: true, core: true, gov: true },
    useBummerConfig,
  )

  // Display summary and get confirmation
  if (await confirmDeployment(network)) {
    // Deploy the TipJar contract
    const deployedTipJar = await deployTipJarContract(config)
    console.log(kleur.green().bold('TipJar deployed successfully!'))
    console.log(kleur.yellow('TipJar Address:'), kleur.cyan(deployedTipJar.tipJar.address))

    // Update config with new TipJar address
    await updateConfig(network, useBummerConfig, deployedTipJar.tipJar.address)

    return deployedTipJar
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }
}

/**
 * Deploys the TipJar contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<TipJarContracts>} The deployed TipJar contract.
 */
async function deployTipJarContract(config: BaseConfig): Promise<TipJarContracts> {
  console.log(kleur.cyan().bold('Deploying TipJar Contract...'))

  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  // Get token from configuration (SUMMER token for TipJar)
  const tokenAddress = getSummerTokenAddress(config)

  console.log(kleur.yellow('SUMMER Token Address:'), kleur.cyan(tokenAddress))

  // Deploy TipJar module
  const tipJarModule = createTipJarModule()
  const deployedModule = (await hre.ignition.deploy(tipJarModule, {
    parameters: {
      TipJarModule: {
        accessManager: getAccessManagerAddress(config),
        configurationManager: getConfigurationManagerAddress(config),
      },
    },
    deploymentId,
  })) as TipJarContracts

  return deployedModule
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {TipStreamsConfig} tipStreamsConfig - The tip streams configuration.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(network: string): Promise<boolean> {
  console.log(kleur.yellow(`TipJar will be redeployed on: ${network}`))

  return await continueDeploymentCheck()
}

/**
 * Updates the configuration file with the new TipJar address
 * @param network The network being deployed to
 * @param useBummerConfig Whether to use the bummer/test config
 * @param tipJarAddress The address of the newly deployed TipJar contract
 */
async function updateConfig(network: string, useBummerConfig: boolean, tipJarAddress: string) {
  try {
    // Read the current config first
    const configFile = useBummerConfig ? 'index.test.json' : 'index.json'
    const indexPath = path.join(__dirname, '..', 'config', configFile)
    const indexJson = JSON.parse(fs.readFileSync(indexPath, 'utf8'))

    // Get the current core contracts (or create if doesn't exist)
    const coreContracts = indexJson[network]?.deployedContracts?.core || {}

    // Update just the tipJar address while preserving others
    const updatedContracts = {
      ...coreContracts,
      tipJar: { address: tipJarAddress },
    }

    // Use the shared helper to update the configuration
    await updateIndexJson('core', network, updatedContracts, useBummerConfig)
  } catch (error) {
    console.error(kleur.red().bold('Failed to update configuration:'), error)
    throw error
  }
}

// Execute the script
redeployTipJar().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { redeployTipJar }
