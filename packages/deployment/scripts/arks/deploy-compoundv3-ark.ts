import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  CompoundV3ArkContracts,
  createCompoundV3ArkModule,
} from '../../ignition/modules/arks/compoundv3-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress } from '../helpers/validation'

export interface CompoundV3ArkUserInput {
  token: { address: Address; symbol: Token }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
}

/**
 * Main function to deploy a CompoundV3Ark.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the CompoundV3Ark contract
 * - Logging deployment results
 */
export async function deployCompoundV3Ark(config: BaseConfig, arkParams?: CompoundV3ArkUserInput) {
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
 * @returns {Promise<CompoundV3ArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<CompoundV3ArkUserInput> {
  // Extract Compound V3 pools from the configuration
  const compoundV3Pools = []
  for (const pool in config.protocolSpecific.compoundV3.pools) {
    compoundV3Pools.push({
      title: pool.toUpperCase(),
      value: pool,
    })
  }

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
  ])

  // Set the token address based on the selected pool
  const selectedPool = responses.compoundV3Pool as Token
  const tokenAddress = config.tokens[selectedPool]

  return {
    ...responses,
    token: { address: tokenAddress, symbol: selectedPool },
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {CompoundV3ArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: CompoundV3ArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
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
 * @param {CompoundV3ArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<CompoundV3ArkContracts>} The deployed CompoundV3Ark contract.
 */
async function deployCompoundV3ArkContract(
  config: BaseConfig,
  userInput: CompoundV3ArkUserInput,
): Promise<CompoundV3ArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `CompoundV3-${userInput.token.symbol}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  const compoundV3Pool = validateAddress(
    config.protocolSpecific.compoundV3.pools[userInput.token.symbol].cToken,
    'Compound V3 Pool',
  )
  const compoundV3Rewards = validateAddress(
    config.protocolSpecific.compoundV3.rewards,
    'Compound V3 Rewards',
  )

  return (await hre.ignition.deploy(createCompoundV3ArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        compoundV3Pool: compoundV3Pool,
        compoundV3Rewards: compoundV3Rewards,
        arkParams: {
          name: `CompoundV3-${userInput.token.symbol}-${chainId}`,
          details: JSON.stringify({
            protocol: 'CompoundV3',
            type: 'Lending',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: compoundV3Pool,
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
  })) as CompoundV3ArkContracts
}
