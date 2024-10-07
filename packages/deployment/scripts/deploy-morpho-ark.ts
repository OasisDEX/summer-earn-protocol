import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { BaseConfig, TokenType } from '../ignition/config/config-types'
import MorphoArkModule, { MorphoArkContracts } from '../ignition/modules/arks/morpho-ark'
import { MAX_UINT256_STRING } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
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

  const userInput = await getUserInput(config)

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
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig) {
  // Extract Morpho markets from the configuration
  const morphoMarkets = []
  for (const token in config.morpho.markets) {
    for (const marketName in config.morpho.markets[token as TokenType]) {
      const marketId = config.morpho.markets[token as TokenType][marketName]
      morphoMarkets.push({
        title: `${token.toUpperCase()} - ${marketName}`,
        value: { token, marketId },
      })
    }
  }

  const responses = await prompts([
    {
      type: 'select',
      name: 'marketSelection',
      message: 'Select a Morpho market:',
      choices: morphoMarkets,
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

  // Set the token address based on the selected market
  const selectedMarket = responses.marketSelection
  const tokenAddress = config.tokens[selectedMarket.token as TokenType]

  return {
    ...responses,
    token: tokenAddress,
    marketId: selectedMarket.marketId,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: any) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token                  : ${userInput.token}`))
  console.log(kleur.yellow(`Market ID              : ${userInput.marketId}`))
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

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
          name: `Morpho-${userInput.token}-${userInput.marketId}-${chainId}`,
          accessManager: config.core.protocolAccessManager,
          configurationManager: config.core.configurationManager,
          token: userInput.token,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
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
