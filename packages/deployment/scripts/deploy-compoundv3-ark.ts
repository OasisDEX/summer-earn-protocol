import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { BaseConfig, TokenType } from '../ignition/config/config-types'
import CompoundV3ArkModule, {
  CompoundV3ArkContracts,
} from '../ignition/modules/arks/compoundv3-ark'
import { MAX_UINT256_STRING } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

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
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig) {
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
    token: tokenAddress,
    compoundV3Pool: config.protocolSpecific.compoundV3.pools[selectedPool].cToken,
    compoundV3Rewards: config.protocolSpecific.compoundV3.rewards,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: any) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Compound V3 Pools: ${userInput.compoundV3Pools.join(', ')}`))
  console.log(kleur.yellow(`Compound V3 Rewards: ${userInput.compoundV3Rewards}`))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return await continueDeploymentCheck()
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
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  return (await hre.ignition.deploy(CompoundV3ArkModule, {
    parameters: {
      CompoundV3ArkModule: {
        compoundV3Pools: userInput.compoundV3Pools,
        compoundV3Rewards: userInput.compoundV3Rewards,
        arkParams: {
          name: `CompoundV3-${userInput.token}-${userInput.compoundV3Pools}-${chainId}`,
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
  })) as CompoundV3ArkContracts
}

// Execute the deployCompoundV3Ark function and handle any errors
deployCompoundV3Ark().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
