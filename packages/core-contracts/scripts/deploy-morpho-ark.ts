import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import MorphoArkModule, { MorphoArkContracts } from '../ignition/modules/morpho-ark'
import { getConfigByNetwork } from './helpers/config-handler'
import { BaseConfig } from '../ignition/config/config-types'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

/**
 * Main function to deploy a MorphoArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MorphoArk contract
 * - Logging deployment results
 */
export async function deployMorphoArk() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting MorphoArk deployment process...'))

  const userInput = await getUserInput()

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedMorphoArk = await deployMorphoArkContract(config, userInput)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logMorphoArk(deployedMorphoArk)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for MorphoArk deployment parameters.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput() {
  return await prompts([
    {
      type: 'text',
      name: 'token',
      message: 'Enter the token address:',
    },
    {
      type: 'text',
      name: 'marketId',
      message: 'Enter the Morpho market ID:',
    },
    {
      type: 'number',
      name: 'maxAllocation',
      message: 'Enter the max allocation:',
    },
  ])
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: any) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Market ID: ${userInput.marketId}`))
  console.log(kleur.yellow(`Max Allocation: ${userInput.maxAllocation}`))

  return await continueDeploymentCheck()
}

/**
 * Deploys the MorphoArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<MorphoArkContracts>} The deployed MorphoArk contract.
 */
async function deployMorphoArkContract(
  config: BaseConfig,
  userInput: any,
): Promise<MorphoArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  return (await hre.ignition.deploy(MorphoArkModule, {
    parameters: {
      MorphoArkModule: {
        morphoBlue: config.morpho.blue,
        marketId: userInput.marketId,
        arkParams: {
          name: 'MorphoArk',
          accessManager: config.core.protocolAccessManager,
          configurationManager: config.core.configurationManager,
          token: userInput.token,
          maxAllocation: userInput.maxAllocation,
        },
      },
    },
    deploymentId,
  })) as MorphoArkContracts
}

// Execute the deployMorphoArk function and handle any errors
deployMorphoArk().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
