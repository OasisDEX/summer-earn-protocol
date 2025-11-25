import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createMorphoArkModule, MorphoArkContracts } from '../../ignition/modules/arks/morpho-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface MorphoArkUserInput extends BaseArkParams {
  marketId: string
  marketName: string
}
/**
 * Main function to deploy a MorphoArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MorphoArk contract
 * - Logging deployment results
 */
export async function deployMorphoArk(config: BaseConfig, arkParams?: MorphoArkUserInput) {
  console.log(kleur.green().bold('Starting MorphoArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedMorphoArk = await deployMorphoArkContract(config, userInput)
    return { ark: deployedMorphoArk.morphoArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for MorphoArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<MorphoArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<MorphoArkUserInput> {
  // Extract Morpho markets from the configuration
  const morphoMarkets = []
  for (const token in config.protocolSpecific.morpho.markets) {
    for (const marketName in config.protocolSpecific.morpho.markets[token as Token]) {
      const marketId = config.protocolSpecific.morpho.markets[token as Token][marketName]
      morphoMarkets.push({
        title: `${token.toUpperCase()} - ${marketName}`,
        value: { token, marketId, marketName },
      })
    }
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'marketSelection',
      message: 'Select a Morpho market:',
      choices: morphoMarkets,
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

  // Set the token address based on the selected market
  const selectedMarket = responses.marketSelection
  const tokenAddress = config.tokens[selectedMarket.token as Token]

  return {
    depositCap: responses.depositCap,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxDepositPercentageOfTVL: responses.maxDepositPercentageOfTVL,
    token: { address: tokenAddress, symbol: selectedMarket.token },
    marketId: selectedMarket.marketId,
    marketName: selectedMarket.marketName,
    fleetName: fleetDefinition.fleetName,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {MorphoArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: MorphoArkUserInput, config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token                  : ${userInput.token}`))
  console.log(kleur.yellow(`Market ID              : ${userInput.marketId}`))
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the MorphoArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {MorphoArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<MorphoArkContracts>} The deployed MorphoArk contract.
 */
async function deployMorphoArkContract(
  config: BaseConfig,
  userInput: MorphoArkUserInput,
): Promise<MorphoArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Morpho-${userInput.token.symbol}-${userInput.marketName}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const urdFactoryAddress = validateAddress(
    config.protocolSpecific.morpho.urdFactory,
    'Morpho URD Factory',
  )
  const blueAddress = validateAddress(config.protocolSpecific.morpho.blue, 'Morpho Blue')

  // Create and validate ark details
  const arkDetails = {
    protocol: 'Morpho',
    type: 'Lending',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: userInput.marketId,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'Morpho ark details')

  return (await hre.ignition.deploy(createMorphoArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        morphoBlue: blueAddress,
        marketId: userInput.marketId,
        urdFactory: urdFactoryAddress,
        arkParams: {
          name: `Morpho-${userInput.token.symbol}-${userInput.marketName}-${chainId}`,
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
  })) as MorphoArkContracts
}
