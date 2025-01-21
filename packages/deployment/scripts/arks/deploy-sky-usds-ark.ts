import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  SkyUsdsArkContracts,
  createSkyUsdsArkModule,
} from '../../ignition/modules/arks/sky-usds-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { ADDRESS_ZERO, HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress } from '../helpers/validation'

export interface SkyUsdsArkUserInput {
  token: { address: Address; symbol: Token }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
}

/**
 * Main function to deploy a SkyUsdsArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the SkyUsdsArk contract
 * - Logging deployment results
 */
export async function deploySkyUsdsArk(config: BaseConfig, arkParams?: SkyUsdsArkUserInput) {
  console.log(kleur.green().bold('Starting SkyUsdsArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedSkyUsdsArk = await deploySkyUsdsArkContract(config, userInput)
    return { ark: deployedSkyUsdsArk.skyUsdsArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for SkyUsdsArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<SkyUsdsArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<SkyUsdsArkUserInput> {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    // Only add tokens that have a corresponding PSM Lite configuration
    const psmLiteAddress = config.protocolSpecific.sky.psmLite[tokenSymbol as Token]
    if (psmLiteAddress && psmLiteAddress != ADDRESS_ZERO) {
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
 * @param {SkyUsdsArkUserInput} userInput - The user's input for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: SkyUsdsArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} (${userInput.token.symbol})`))
  console.log(
    kleur.yellow(`PSM Lite: ${config.protocolSpecific.sky.psmLite[userInput.token.symbol]}`),
  )
  console.log(kleur.yellow(`USDS: ${config.tokens.usds}`))
  console.log(kleur.yellow(`Staked USDS: ${config.tokens.stakedUsds}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the SkyUsdsArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {SkyUsdsArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<SkyUsdsArkContracts>} The deployed SkyUsdsArk contract.
 */
async function deploySkyUsdsArkContract(
  config: BaseConfig,
  userInput: SkyUsdsArkUserInput,
): Promise<SkyUsdsArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `SkyUsds-${userInput.token.symbol}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  const psmLiteAddress = validateAddress(
    config.protocolSpecific.sky.psmLite[userInput.token.symbol],
    'PSM Lite',
  )
  const usdsAddress = validateAddress(config.tokens.usds, 'USDS')
  const stakedUsdsAddress = validateAddress(config.tokens.stakedUsds, 'Staked USDS')

  return (await hre.ignition.deploy(createSkyUsdsArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        litePsm: psmLiteAddress,
        usds: usdsAddress,
        stakedUsds: stakedUsdsAddress,

        arkParams: {
          name: arkName,
          details: JSON.stringify({
            protocol: 'Sky',
            type: 'Staking',
            asset: userInput.token.address,
            marketAsset: config.tokens.usds,
            pool: psmLiteAddress,
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
  })) as SkyUsdsArkContracts
}
