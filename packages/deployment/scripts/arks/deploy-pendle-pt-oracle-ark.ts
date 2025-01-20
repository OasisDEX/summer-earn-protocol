import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createPendlePtOracleArkModule,
  PendlePtOracleArkContracts,
} from '../../ignition/modules/arks/pendle-pt-oracle-ark'
import { BaseConfig, Tokens, TokenType } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

export interface PendlePtOracleArkUserInput {
  marketAssetOracle: Address
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  token: { address: Address; symbol: Tokens }
  marketId: Address
  marketName: string
}

export async function deployPendlePTOracleArk(
  config: BaseConfig,
  arkParams: PendlePtOracleArkUserInput | undefined,
) {
  console.log(kleur.green().bold('Starting PendlePtOracleArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedPendlePtOracleArk = await deployPendlePtOracleArkContract(config, userInput)
    return { ark: deployedPendlePtOracleArk.pendlePtOracleArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<PendlePtOracleArkUserInput> {
  // Extract Pendle markets from the configuration
  const pendleMarkets = []
  if (!config.protocolSpecific.pendle || !config.protocolSpecific.pendle.markets) {
    throw new Error('No Pendle markets found in the configuration.')
  }

  for (const token in config.protocolSpecific.pendle.markets) {
    const marketConfig = config.protocolSpecific.pendle.markets[token as Tokens]
    for (const marketName in marketConfig.marketAddresses) {
      const marketId = marketConfig.marketAddresses[marketName]
      const marketAssetAddress = config.tokens[token as TokenType]
      pendleMarkets.push({
        title: `Market Asset: ${token.toUpperCase()} - Market Name: ${marketName}`,
        value: { token: { address: marketAssetAddress, symbol: token }, marketId, marketName },
      })
    }
  }

  // First prompt for market selection
  const marketResponse = await prompts({
    type: 'select',
    name: 'marketSelection',
    message: 'Select a Pendle market:',
    choices: pendleMarkets,
  })

  const selectedMarketAsset = marketResponse.marketSelection.token
  const selectedMarketConfig =
    config.protocolSpecific.pendle.markets[selectedMarketAsset.symbol as Tokens]
  const arkAssetChoices = selectedMarketConfig.swapInTokens.map((arkAsset) => ({
    title: `Ark Asset: ${arkAsset.token.toUpperCase()} - Oracle: ${arkAsset.oracle}`,
    value: arkAsset,
  }))

  // Then prompt for ark asset selection
  const arkAssetResponse = await prompts({
    type: 'select',
    name: 'arkAssetSelection',
    message: 'Select a swap ark/fleet asset:',
    choices: arkAssetChoices,
  })

  // Rest of the prompts
  const responses = await prompts([
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
  const selectedMarket = marketResponse.marketSelection
  const arkAssetAddress = config.tokens[arkAssetResponse.arkAssetSelection.token as TokenType]

  const aggregatedData = {
    ...responses,
    marketAssetOracle: arkAssetResponse.arkAssetSelection.oracle,
    token: { address: arkAssetAddress, symbol: arkAssetResponse.arkAssetSelection.token },
    marketId: selectedMarket.marketId,
    marketName: selectedMarket.marketName,
  }

  return aggregatedData
}

async function confirmDeployment(
  userInput: PendlePtOracleArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Market ID: ${userInput.marketId}`))
  console.log(kleur.yellow(`Market Asset Oracle: ${userInput.marketAssetOracle}`))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployPendlePtOracleArkContract(
  config: BaseConfig,
  userInput: PendlePtOracleArkUserInput,
): Promise<PendlePtOracleArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `PendlePt-${userInput.token.symbol}-${userInput.marketName}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  const routerAddress = config.protocolSpecific.pendle.router
  const oracleAddress = config.protocolSpecific.pendle['lp-oracle']

  return (await hre.ignition.deploy(createPendlePtOracleArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        market: userInput.marketId,
        oracle: oracleAddress,
        router: routerAddress,
        marketAssetOracle: userInput.marketAssetOracle,
        arkParams: {
          name: `PendlePt-${userInput.token.symbol}-${userInput.marketName}-${chainId}`,
          details: JSON.stringify({
            protocol: 'Pendle',
            type: 'PtOracle',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: userInput.marketId,
            chainId: chainId,
          }),
          accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
          asset: userInput.token.address,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: true,
          maxDepositPercentageOfTVL: HUNDRED_PERCENT,
        },
      },
    },
    deploymentId,
  })) as PendlePtOracleArkContracts
}
