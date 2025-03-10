import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { TipJarContracts, createTipJarModule } from '../ignition/modules/tipjar'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'

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
  const tokenAddress = config.deployedContracts.gov.summerToken.address
  if (!tokenAddress) {
    throw new Error('SUMMER token address not found in configuration')
  }

  console.log(kleur.yellow('SUMMER Token Address:'), kleur.cyan(tokenAddress))

  // Deploy TipJar module
  return (await hre.ignition.deploy(
    createTipJarModule({
      token: tokenAddress as Address,
    }),
    {
      deploymentId,
    },
  )) as TipJarContracts
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

// Execute the script
redeployTipJar().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export { redeployTipJar }
