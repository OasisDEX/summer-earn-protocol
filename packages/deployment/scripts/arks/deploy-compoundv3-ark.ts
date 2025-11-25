import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  CompoundV3ArkContracts,
  createCompoundV3ArkModule,
} from '../../ignition/modules/arks/compoundv3-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

/**
 * Main function to deploy a CompoundV3Ark.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the CompoundV3Ark contract
 * - Logging deployment results
 */
export async function deployCompoundV3Ark(config: BaseConfig, arkParams?: BaseArkParams) {
  console.log(kleur.green().bold('Starting CompoundV3Ark deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedCompoundV3Ark = await deployCompoundV3ArkContract(config, userInput)
    return { ark: deployedCompoundV3Ark.compoundV3Ark }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for CompoundV3Ark deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<BaseArkParams>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<BaseArkParams> {
  // Extract Compound V3 pools from the configuration
  const compoundV3Pools = []
  for (const pool in config.protocolSpecific.compoundV3.pools) {
    compoundV3Pools.push({
      title: pool.toUpperCase(),
      value: pool,
    })
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'compoundV3Pool',
      message: 'Select Compound V3 pools:',
      choices: compoundV3Pools,
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

  // Set the token address based on the selected pool
  const selectedPool = responses.compoundV3Pool as Token
  const tokenAddress = config.tokens[selectedPool]

  return {
    ...responses,
    token: { address: tokenAddress, symbol: selectedPool },
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
  console.log(kleur.yellow(`Token: ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the CompoundV3Ark contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {BaseArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<CompoundV3ArkContracts>} The deployed CompoundV3Ark contract.
 */
async function deployCompoundV3ArkContract(
  config: BaseConfig,
  userInput: BaseArkParams,
): Promise<CompoundV3ArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `CompoundV3-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const compoundV3Pool = validateAddress(
    config.protocolSpecific.compoundV3.pools[userInput.token.symbol].cToken,
    'Compound V3 Pool',
  )
  const compoundV3Rewards = validateAddress(
    config.protocolSpecific.compoundV3.rewards,
    'Compound V3 Rewards',
  )

  // Create and validate ark details
  const arkDetails = {
    protocol: 'CompoundV3',
    type: 'Lending',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: compoundV3Pool,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'CompoundV3 ark details')

  return (await hre.ignition.deploy(createCompoundV3ArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        compoundV3Pool: compoundV3Pool,
        compoundV3Rewards: compoundV3Rewards,
        arkParams: {
          name: arkName,
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
  })) as CompoundV3ArkContracts
}
