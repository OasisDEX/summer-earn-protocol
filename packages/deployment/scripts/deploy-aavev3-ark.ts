import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { BaseConfig, TokenType } from '../ignition/config/config-types'
import AaveV3ArkModule, { AaveV3ArkContracts } from '../ignition/modules/arks/aavev3-ark'
import { MAX_UINT256_STRING } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

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

  const userInput = await getUserInput(config)

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
 * Prompts the user for CompoundV3Ark deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig) {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as TokenType]
    tokens.push({
      title: tokenSymbol.toUpperCase(),
      value: tokenAddress,
    })
  }

  return await prompts([
    {
      type: 'select',
      name: 'token',
      message: 'Select token :',
      choices: tokens,
    },
    {
      type: 'text',
      name: 'depositCap',
      initial: MAX_UINT256_STRING,
      message: 'Enter the deposit cap:',
    },
    {
      type: 'text',
      name: 'maxRebalanceOutflow',
      initial: MAX_UINT256_STRING,
      message: 'Enter the max rebalance outflow:',
    },
    {
      type: 'text',
      name: 'maxRebalanceInflow',
      initial: MAX_UINT256_STRING,
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

  return await continueDeploymentCheck()
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
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  return (await hre.ignition.deploy(AaveV3ArkModule, {
    parameters: {
      AaveV3ArkModule: {
        aaveV3Pool: config.protocolSpecific.aaveV3.pool,
        rewardsController: config.protocolSpecific.aaveV3.rewards,
        arkParams: {
          name: `AaveV3-${userInput.token}-${config.protocolSpecific.aaveV3.pool}-${chainId}`,
          accessManager: config.deployedContracts.core.protocolAccessManager,
          configurationManager: config.deployedContracts.core.configurationManager,
          token: userInput.token,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
        },
      },
    },
    deploymentId,
  })) as AaveV3ArkContracts
}

// Execute the deployAaveV3Ark function and handle any errors
deployAaveV3Ark().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
