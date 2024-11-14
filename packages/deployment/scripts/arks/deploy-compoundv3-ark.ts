import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import CompoundV3ArkModule, {
  CompoundV3ArkContracts,
} from '../../ignition/modules/arks/compoundv3-ark'
import { BaseConfig, TokenType } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

interface CompoundV3ArkUserInput {
  compoundV3Pool: Address
  compoundV3Rewards: Address
  token: { address: Address; symbol: string }
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
export async function deployCompoundV3Ark() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting CompoundV3Ark deployment process...'))

  const userInput = await getUserInput(config)

  if (await confirmDeployment(userInput)) {
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
  const selectedPool = responses.compoundV3Pool as TokenType
  const tokenAddress = config.tokens[selectedPool]

  return {
    ...responses,
    token: { address: tokenAddress, symbol: selectedPool },
    compoundV3Pool: config.protocolSpecific.compoundV3.pools[selectedPool].cToken,
    compoundV3Rewards: config.protocolSpecific.compoundV3.rewards,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {CompoundV3ArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: CompoundV3ArkUserInput) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Compound V3 Pool: ${userInput.compoundV3Pool}`))
  console.log(kleur.yellow(`Compound V3 Rewards: ${userInput.compoundV3Rewards}`))
  console.log(kleur.yellow(`Token: ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return await continueDeploymentCheck()
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

  return (await hre.ignition.deploy(CompoundV3ArkModule, {
    parameters: {
      CompoundV3ArkModule: {
        compoundV3Pool: userInput.compoundV3Pool,
        compoundV3Rewards: userInput.compoundV3Rewards,
        arkParams: {
          name: `CompoundV3-${userInput.token.symbol}-${chainId}`,
          details: JSON.stringify({
            protocol: 'CompoundV3',
            type: 'Lending',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: userInput.compoundV3Pool,
            chainId: chainId,
          }),
          accessManager: config.deployedContracts.core.protocolAccessManager.address as Address,
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
