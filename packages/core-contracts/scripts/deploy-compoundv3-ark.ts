import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import CompoundV3ArkModule, { CompoundV3ArkContracts } from '../ignition/modules/compoundv3-ark'
import { getConfigByNetwork } from './config-handler'
import { BaseConfig } from './config-types'
import { ModuleLogger } from './module-logger'

/**
 * Main function to deploy a CompoundV3Ark.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the CompoundV3Ark contract
 * - Logging deployment results
 */
export async function deployCompoundV3Ark() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting CompoundV3Ark deployment process...'))

  const userInput = await getUserInput()

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedCompoundV3Ark = await deployCompoundV3ArkContract(config, userInput)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logCompoundV3Ark(deployedCompoundV3Ark)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for CompoundV3Ark deployment parameters.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput() {
  return await prompts([
    {
      type: 'text',
      name: 'compoundV3Pool',
      message: 'Enter the Compound V3 Pool address:',
    },
    {
      type: 'text',
      name: 'compoundV3Rewards',
      message: 'Enter the Compound V3 Rewards address:',
    },
    {
      type: 'text',
      name: 'token',
      message: 'Enter the token address:',
    },
    {
      type: 'number',
      name: 'depositCap',
      message: 'Enter the deposit cap:',
    },
    {
      type: 'number',
      name: 'maxRebalanceOutflow',
      message: 'Enter the max rebalance outflow:',
    },
    {
      type: 'number',
      name: 'maxRebalanceInflow',
      message: 'Enter the max rebalance inflow:',
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
  console.log(kleur.yellow(`Compound V3 Pool: ${userInput.compoundV3Pool}`))
  console.log(kleur.yellow(`Compound V3 Rewards: ${userInput.compoundV3Rewards}`))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: 'Do you want to continue with the deployment?',
  })

  return confirmed
}

/**
 * Deploys the CompoundV3Ark contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<CompoundV3ArkContracts>} The deployed CompoundV3Ark contract.
 */
async function deployCompoundV3ArkContract(
  config: BaseConfig,
  userInput: any,
): Promise<CompoundV3ArkContracts> {
  return (await hre.ignition.deploy(CompoundV3ArkModule, {
    parameters: {
      CompoundV3ArkModule: {
        compoundV3Pool: userInput.compoundV3Pool,
        compoundV3Rewards: userInput.compoundV3Rewards,
        arkParams: {
          name: 'CompoundV3Ark',
          accessManager: config.core.protocolAccessManager,
          configurationManager: config.core.configurationManager,
          token: userInput.token,
          maxAllocation: userInput.depositCap,
        },
      },
    },
  })) as CompoundV3ArkContracts
}

// Execute the deployCompoundV3Ark function and handle any errors
deployCompoundV3Ark().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
