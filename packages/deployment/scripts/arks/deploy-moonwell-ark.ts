import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createMoonwellArkModule,
  MoonwellArkContracts,
} from '../../ignition/modules/arks/moonwell-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress } from '../helpers/validation'

export interface MoonwellArkUserInput {
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  token: { address: Address; symbol: Token }
}
/**
 * Main function to deploy a MoonwellArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MoonwellArk contract
 * - Logging deployment results
 */
export async function deployMoonwellArk(config: BaseConfig, arkParams?: MoonwellArkUserInput) {
  console.log(kleur.green().bold('Starting MoonwellArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedMoonwellArk = await deployMoonwellArkContract(config, userInput)
    return { ark: deployedMoonwellArk.moonwellArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for MoonwellArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<MoonwellArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<MoonwellArkUserInput> {
  // Extract Moonwell markets from the configuration
  const moonwellMTokens = []
  for (const token in config.protocolSpecific.moonwell.pools) {
    moonwellMTokens.push({
      title: `${token.toUpperCase()}`,
      value: token,
    })
  }

  const responses = await prompts([
    {
      type: 'select',
      name: 'mTokenSelection',
      message: 'Select a Moonwell mToken:',
      choices: moonwellMTokens,
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
  const selectedMarket = responses.mTokenSelection
  const tokenAddress = config.tokens[selectedMarket as Token]

  return {
    ...responses,
    token: { address: tokenAddress, symbol: selectedMarket },
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {MoonwellArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: MoonwellArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token                  : ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the MoonwellArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {MoonwellArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<MoonwellArkContracts>} The deployed MoonwellArk contract.
 */
async function deployMoonwellArkContract(
  config: BaseConfig,
  userInput: MoonwellArkUserInput,
): Promise<MoonwellArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Moonwell-${userInput.token.symbol}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  const mToken = validateAddress(
    config.protocolSpecific.moonwell.pools[userInput.token.symbol].mToken,
    'Moonwell mToken',
  )

  return (await hre.ignition.deploy(createMoonwellArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        mToken: mToken,
        arkParams: {
          name: arkName,
          details: JSON.stringify({
            protocol: 'Moonwell',
            type: 'Lending',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: mToken,
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
  })) as MoonwellArkContracts
}
