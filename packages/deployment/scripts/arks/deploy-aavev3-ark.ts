import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { AaveV3ArkContracts, createAaveV3ArkModule } from '../../ignition/modules/arks/aavev3-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

/**
 * Main function to deploy an AaveV3Ark.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the AaveV3Ark contract
 * - Logging deployment results
 */
export async function deployAaveV3Ark(config: BaseConfig, arkParams?: BaseArkParams) {
  console.log(kleur.green().bold('Starting AaveV3Ark deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedAaveV3Ark = await deployAaveV3ArkContract(config, userInput)
    return { ark: deployedAaveV3Ark.aaveV3Ark }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}
/**
 * Prompts the user for CompoundV3Ark deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
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
  const reponses = await prompts([
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
    ...reponses,
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
 * Deploys the AaveV3Ark contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {BaseArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<AaveV3ArkContracts>} The deployed AaveV3Ark contract.
 */
async function deployAaveV3ArkContract(
  config: BaseConfig,
  userInput: BaseArkParams,
): Promise<AaveV3ArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `AaveV3-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const aaveV3Pool = validateAddress(config.protocolSpecific.aaveV3.pool, 'aaveV3 pool')
  const aaveV3Rewards = validateAddress(config.protocolSpecific.aaveV3.rewards, 'aaveV3 rewards')

  // Create and validate ark details
  const arkDetails = {
    protocol: 'AaveV3',
    type: 'Lending',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: aaveV3Pool,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'AaveV3 ark details')

  return (await hre.ignition.deploy(createAaveV3ArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        aaveV3Pool: aaveV3Pool,
        rewardsController: aaveV3Rewards,
        arkParams: {
          name: `AaveV3-${userInput.token.symbol}-${chainId}`,
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
  })) as AaveV3ArkContracts
}
