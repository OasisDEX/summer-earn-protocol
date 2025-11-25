import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { SparkArkContracts, createSparkArkModule } from '../../ignition/modules/arks/spark-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

/**
 * Main function to deploy a SparkArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the SparkArk contract
 * - Logging deployment results
 */
export async function deploySparkArk(config: BaseConfig, arkParams?: BaseArkParams) {
  console.log(kleur.green().bold('Starting SparkArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedSparkArk = await deploySparkArkContract(config, userInput)
    return { ark: deployedSparkArk.sparkArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for SparkArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<BaseArkParams>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<BaseArkParams> {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    tokens.push({
      title: tokenSymbol,
      value: { address: tokenAddress, symbol: tokenSymbol },
    })
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
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
    {
      type: 'text',
      name: 'maxDepositPercentageOfTVL',
      initial: HUNDRED_PERCENT,
      message: 'Enter the max deposit percentage of TVL:',
    },
  ])
  return {
    ...responses,
    fleetName: fleetDefinition.fleetName,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {BaseArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: BaseArkParams, config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} (${userInput.token.symbol})`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the SparkArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {BaseArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<SparkArkContracts>} The deployed SparkArk contract.
 */
async function deploySparkArkContract(
  config: BaseConfig,
  userInput: BaseArkParams,
): Promise<SparkArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Spark-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const sparkPool = validateAddress(config.protocolSpecific.spark.pool, 'spark pool')
  const sparkRewards = validateAddress(config.protocolSpecific.spark.rewards, 'spark rewards')

  // Create and validate ark details
  const arkDetails = {
    protocol: 'Spark',
    type: 'Lending',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: sparkPool,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'Spark ark details')

  return (await hre.ignition.deploy(createSparkArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        sparkPool: sparkPool,
        rewardsController: sparkRewards,
        arkParams: {
          name: `Spark-${userInput.token.symbol}-${chainId}`,
          details: JSON.stringify(arkDetails),
          accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
          asset: userInput.token.address,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
          maxDepositPercentageOfTVL: userInput.maxDepositPercentageOfTVL,
        },
      },
    },
    deploymentId,
  })) as SparkArkContracts
}
