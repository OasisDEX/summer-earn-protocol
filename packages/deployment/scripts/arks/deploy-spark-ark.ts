import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { SparkArkContracts, createSparkArkModule } from '../../ignition/modules/arks/spark-ark'
import { BaseConfig, TokenType } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

interface SparkArkUserInput {
  token: { address: Address; symbol: string }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
}

/**
 * Main function to deploy a SparkArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the SparkArk contract
 * - Logging deployment results
 */
export async function deploySparkArk() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting SparkArk deployment process...'))

  const userInput = await getUserInput(config)

  if (await confirmDeployment(userInput)) {
    const deployedSparkArk = await deploySparkArkContract(config, userInput)
    return { ark: deployedSparkArk.sparkArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for SparkArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<SparkArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<SparkArkUserInput> {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as TokenType]
    tokens.push({
      title: tokenSymbol,
      value: { address: tokenAddress, symbol: tokenSymbol },
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
 * @param {SparkArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: SparkArkUserInput) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} (${userInput.token.symbol})`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return await continueDeploymentCheck()
}

/**
 * Deploys the SparkArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {SparkArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<SparkArkContracts>} The deployed SparkArk contract.
 */
async function deploySparkArkContract(
  config: BaseConfig,
  userInput: SparkArkUserInput,
): Promise<SparkArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Spark-${userInput.token.symbol}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  return (await hre.ignition.deploy(createSparkArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        sparkPool: config.protocolSpecific.spark.pool,
        rewardsController: config.protocolSpecific.spark.rewards,
        arkParams: {
          name: `Spark-${userInput.token.symbol}-${chainId}`,
          details: JSON.stringify({
            protocol: 'Spark',
            type: 'Lending',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: config.protocolSpecific.spark.pool,
            chainId: chainId,
          }),
          accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
          asset: userInput.token.address,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
          maxDepositPercentageOfTVL: HUNDRED_PERCENT,
        },
      },
    },
    deploymentId,
  })) as SparkArkContracts
}
