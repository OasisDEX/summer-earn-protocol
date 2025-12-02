import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createPendlePTArkModule,
  PendlePTArkContracts,
} from '../../ignition/modules/arks/pendle-pt-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface PendlePTArkUserInput extends BaseArkParams {
  marketId: string
  marketName: string
}

export async function deployPendlePTArk(config: BaseConfig, arkParams?: PendlePTArkUserInput) {
  console.log(kleur.green().bold('Starting PendlePTArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedPendlePTArk = await deployPendlePTArkContract(config, userInput)
    return { ark: deployedPendlePTArk.pendlePTArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig) {
  // Extract Pendle markets from the configuration
  const pendleMarkets = []
  if (!config.protocolSpecific.pendle || !config.protocolSpecific.pendle.markets) {
    throw new Error('No Pendle markets found in the configuration.')
  }
  for (const token in config.protocolSpecific.pendle.markets) {
    for (const marketName in config.protocolSpecific.pendle.markets[token as Token]
      .marketAddresses) {
      const marketId =
        config.protocolSpecific.pendle.markets[token as Token].marketAddresses[marketName]
      pendleMarkets.push({
        title: `${token.toUpperCase()} - ${marketName}`,
        value: {
          token: { address: config.tokens[token as Token], symbol: token },
          marketId,
          marketName,
        },
      })
    }
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'marketSelection',
      message: 'Select a Pendle market:',
      choices: pendleMarkets,
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

  const aggregatedData = {
    depositCap: responses.depositCap,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxDepositPercentageOfTVL: responses.maxDepositPercentageOfTVL,
    token: { address: tokenAddress, symbol: selectedMarket.token },
    marketId: selectedMarket.marketId,
    marketName: selectedMarket.marketName,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

async function confirmDeployment(
  userInput: PendlePTArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Market ID: ${userInput.marketId}`))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployPendlePTArkContract(
  config: BaseConfig,
  userInput: PendlePTArkUserInput,
): Promise<PendlePTArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `PendlePt-${userInput.token}-${userInput.marketId}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const routerAddress = validateAddress(config.protocolSpecific.pendle.router, 'Pendle Router')
  const oracleAddress = validateAddress(
    config.protocolSpecific.pendle['lp-oracle'],
    'Pendle LP Oracle',
  )

  // Create and validate ark details

  const arkDetails = {
    protocol: 'Pendle',
    type: 'Pt',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: userInput.marketId,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'PendlePt ark details')

  return (await hre.ignition.deploy(createPendlePTArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        market: userInput.marketId,
        oracle: oracleAddress,
        router: routerAddress,
        arkParams: {
          name: `PendlePt-${userInput.token}-${userInput.marketId}-${chainId}`,
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
  })) as PendlePTArkContracts
}
