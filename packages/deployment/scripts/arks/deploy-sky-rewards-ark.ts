import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  SkyRewardsArkContracts,
  createSkyRewardsArkModule,
} from '../../ignition/modules/arks/sky-rewards-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { ADDRESS_ZERO, HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import {
  validateAddress,
  validateArkDetails,
  validateConfigAddressEntry,
} from '../helpers/validation'

type SkyRewardsArkUserInput = BaseArkParams & {
  rewardToken?: string
}

function getAvailableRewardsPrograms(config: BaseConfig): string[] {
  return Object.entries(config.protocolSpecific.sky.staking)
    .filter(([, address]) => address && address !== ADDRESS_ZERO)
    .map(([key]) => key)
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
export async function deploySkyRewardsArk(config: BaseConfig, arkParams?: SkyRewardsArkUserInput) {
  console.log(kleur.green().bold('Starting SkyRewardsArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedSkyRewardsArk = await deploySkyRewardsArkContract(config, userInput)
    return { ark: deployedSkyRewardsArk.skyRewardsArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for SkyUsdsArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<SkyUsdsArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<SkyRewardsArkUserInput> {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    // Only add tokens that have a corresponding PSM Lite configuration
    const psmLiteAddress = config.protocolSpecific.sky.psmLite[tokenSymbol as Token]
    if (psmLiteAddress && psmLiteAddress != ADDRESS_ZERO) {
      tokens.push({
        title: tokenSymbol.toUpperCase(),
        value: { address: tokenAddress, symbol: tokenSymbol as Token },
      })
    }
  }

  const stakingRewardsChoices = getAvailableRewardsPrograms(config).map((key) => ({
    title: key.toUpperCase(),
    value: key,
  }))

  const fleetDefinition = await getFleetConfig()
  const reponses = await prompts([
    {
      type: 'select',
      name: 'token',
      message: 'Select token:',
      choices: tokens,
    },
    {
      type: 'select',
      name: 'rewardToken',
      message: 'Select rewards program:',
      choices: stakingRewardsChoices,
      initial: 0,
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
    fleetName: fleetDefinition.fleetName,
    ...reponses,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {BaseArkParams} userInput - The user's input for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: SkyRewardsArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(
    kleur.yellow(
      `Token: ${userInput.token.address} (${String(userInput.token.symbol).toUpperCase()})`,
    ),
  )
  console.log(
    kleur.yellow(`PSM Lite: ${config.protocolSpecific.sky.psmLite[userInput.token.symbol]}`),
  )
  const stakingRewardsAddress = validateConfigAddressEntry(
    config.protocolSpecific.sky.staking,
    userInput.rewardToken,
    'Staking Rewards',
  )
  console.log(kleur.yellow(`Rewards program: ${String(userInput.rewardToken).toUpperCase()}`))
  console.log(kleur.yellow(`Staking Rewards: ${stakingRewardsAddress}`))
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
async function deploySkyRewardsArkContract(
  config: BaseConfig,
  userInput: SkyRewardsArkUserInput,
): Promise<SkyRewardsArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const rewardsKey = userInput.rewardToken
  const tokenSymbol = String(userInput.token.symbol).toUpperCase()
  const arkName = `SkyRewards-${String(rewardsKey).toUpperCase()}-${tokenSymbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const psmLiteAddress = validateAddress(
    config.protocolSpecific.sky.psmLite[userInput.token.symbol],
    'PSM Lite',
  )
  const usdsAddress = validateAddress(config.tokens.usds, 'USDS')
  const stakingRewardsAddress = validateConfigAddressEntry(
    config.protocolSpecific.sky.staking,
    rewardsKey,
    'Staking Rewards',
  )

  // Create and validate ark details

  const arkDetails = {
    protocol: 'Sky',
    type: 'Rewards',
    rewardsProgram: String(rewardsKey).toUpperCase(),
    asset: userInput.token.address,
    marketAsset: config.tokens.usds,
    pool: stakingRewardsAddress,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'SkyRewards ark details')

  return (await hre.ignition.deploy(createSkyRewardsArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        litePsm: psmLiteAddress,
        usds: usdsAddress,
        stakingRewards: stakingRewardsAddress,
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
  })) as SkyRewardsArkContracts
}
