import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import AaveV3ArkModule, { AaveV3ArkContracts } from '../ignition/modules/aavev3-ark'
import { getConfigByNetwork } from './helpers/config-handler'
import { BaseConfig } from '../ignition/config/config-types'
import { ModuleLogger } from './helpers/module-logger'

/**
 * Main function to deploy an AaveV3Ark.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the AaveV3Ark contract
 * - Logging deployment results
 */
export async function deployAaveV3Ark() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting AaveV3Ark deployment process...'))

  const userInput = await getUserInput()

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedAaveV3Ark = await deployAaveV3ArkContract(config, userInput)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logAaveV3Ark(deployedAaveV3Ark)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for AaveV3Ark deployment parameters.
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
 * Deploys the AaveV3Ark contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<AaveV3ArkContracts>} The deployed AaveV3Ark contract.
 */
async function deployAaveV3ArkContract(
  config: BaseConfig,
  userInput: any,
): Promise<AaveV3ArkContracts> {
  return (await hre.ignition.deploy(AaveV3ArkModule, {
    parameters: {
      AaveV3ArkModule: {
        aaveV3Pool: config.aaveV3.pool,
        rewardsController: config.aaveV3.rewards,
        arkParams: {
          name: 'AaveV3Ark',
          accessManager: config.core.protocolAccessManager,
          configurationManager: config.core.configurationManager,
          token: userInput.token,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
        },
      },
    },
  })) as AaveV3ArkContracts
}

// Execute the deployAaveV3Ark function and handle any errors
deployAaveV3Ark().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
