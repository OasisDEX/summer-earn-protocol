import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  SkyUsdsPsm3ArkContracts,
  createSkyUsdsPsm3ArkModule,
} from '../../ignition/modules/arks/sky-usds-psm3-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { ADDRESS_ZERO, HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress } from '../helpers/validation'

export interface SkyUsdsPsm3ArkUserInput {
  token: { address: Address; symbol: Token }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
}

/**
 * Main function to deploy a SkyUsdsPsm3Ark.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the SkyUsdsPsm3Ark contract
 * - Logging deployment results
 */
export async function deploySkyUsdsPsm3Ark(
  config: BaseConfig,
  arkParams?: SkyUsdsPsm3ArkUserInput,
) {
  console.log(kleur.green().bold('Starting SkyUsdsPsm3Ark deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedSkyUsdsPsm3Ark = await deploySkyUsdsPsm3ArkContract(config, userInput)
    return { ark: deployedSkyUsdsPsm3Ark.skyUsdsPsm3Ark }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for SkyUsdsPsm3Ark deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<SkyUsdsPsm3ArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<SkyUsdsPsm3ArkUserInput> {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    // Only add tokens that have a corresponding PSM3 configuration
    const psm3Address = config.protocolSpecific.sky.psm3[tokenSymbol as Token]
    if (psm3Address && psm3Address != ADDRESS_ZERO) {
      tokens.push({
        title: tokenSymbol.toUpperCase(),
        value: { address: tokenAddress, symbol: tokenSymbol.toUpperCase() },
      })
    }
  }

  return await prompts([
    {
      type: 'select',
      name: 'token',
      message: 'Select token:',
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
 * @param {SkyUsdsPsm3ArkUserInput} userInput - The user's input for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: SkyUsdsPsm3ArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} (${userInput.token.symbol})`))
  console.log(kleur.yellow(`PSM3: ${config.protocolSpecific.sky.psm3[userInput.token.symbol]}`))
  console.log(kleur.yellow(`sUSDS: ${config.tokens.stakedUsds}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the SkyUsdsPsm3Ark contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {SkyUsdsPsm3ArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<SkyUsdsPsm3ArkContracts>} The deployed SkyUsdsPsm3Ark contract.
 */
async function deploySkyUsdsPsm3ArkContract(
  config: BaseConfig,
  userInput: SkyUsdsPsm3ArkUserInput,
): Promise<SkyUsdsPsm3ArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `SkyUsds-${userInput.token.symbol}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  const psm3Address = validateAddress(
    config.protocolSpecific.sky.psm3[userInput.token.symbol],
    'PSM3',
  )
  const stakedUsdsAddress = validateAddress(config.tokens.stakedUsds, 'Staked USDS')

  return (await hre.ignition.deploy(createSkyUsdsPsm3ArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        psm3: psm3Address,
        susds: stakedUsdsAddress,
        arkParams: {
          name: arkName,
          details: JSON.stringify({
            protocol: 'Sky',
            type: 'Staking',
            asset: userInput.token.address,
            marketAsset: config.tokens.stakedUsds,
            pool: psm3Address,
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
  })) as SkyUsdsPsm3ArkContracts
}
