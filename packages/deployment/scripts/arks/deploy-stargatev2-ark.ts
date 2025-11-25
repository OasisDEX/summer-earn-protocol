import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  StargateV2PoolArkContracts,
  createStargateV2PoolArkModule,
} from '../../ignition/modules/arks/stargatev2-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface StargateV2ArkParams extends BaseArkParams {
  stargatePoolAddress: Address
}

/**
 * Main function to deploy a StargateV2PoolArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the StargateV2PoolArk contract
 * - Logging deployment results
 */
export async function deployStargateV2PoolArk(config: BaseConfig, arkParams?: StargateV2ArkParams) {
  console.log(kleur.green().bold('Starting StargateV2PoolArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedStargateV2PoolArk = await deployStargateV2PoolArkContract(config, userInput)
    return { ark: deployedStargateV2PoolArk.stargateV2PoolArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for StargateV2PoolArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<StargateV2ArkParams>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<StargateV2ArkParams> {
  // Extract Stargate V2 pools from the configuration
  const stargateV2Pools = []
  for (const pool in config.protocolSpecific.stargate.pools) {
    stargateV2Pools.push({
      title: pool.toUpperCase(),
      value: pool,
    })
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'stargateV2Pool',
      message: 'Select Stargate V2 pool:',
      choices: stargateV2Pools,
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
  const selectedPool = responses.stargateV2Pool as Token
  const tokenAddress = config.tokens[selectedPool]
  const stargatePoolAddress = config.protocolSpecific.stargate.pools[selectedPool]

  return {
    ...responses,
    token: { address: tokenAddress, symbol: selectedPool },
    stargatePoolAddress: stargatePoolAddress,
    fleetName: fleetDefinition.fleetName,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {StargateV2ArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: StargateV2ArkParams,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Stargate Pool: ${userInput.stargatePoolAddress}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the StargateV2PoolArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {StargateV2ArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<StargateV2PoolArkContracts>} The deployed StargateV2PoolArk contract.
 */
async function deployStargateV2PoolArkContract(
  config: BaseConfig,
  userInput: StargateV2ArkParams,
): Promise<StargateV2PoolArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `StargateV2-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const stargatePool = validateAddress(userInput.stargatePoolAddress, 'Stargate V2 Pool')
  const stargateStaking = validateAddress(
    config.protocolSpecific.stargate.staking,
    'Stargate V2 Staking',
  )
  const wethAddress = validateAddress(config.tokens.weth, 'WETH')

  // Create and validate ark details

  const arkDetails = {
    protocol: 'StargateV2',
    type: 'Liquidity Pool',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: stargatePool,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'Stargatev2 ark details')

  return (await hre.ignition.deploy(createStargateV2PoolArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        stargatePool: stargatePool,
        stargateStaking: stargateStaking,
        weth: wethAddress,
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
  })) as StargateV2PoolArkContracts
}
