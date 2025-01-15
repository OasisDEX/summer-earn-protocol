import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createPendleLPArkModule,
  PendleLPArkContracts,
} from '../../ignition/modules/arks/pendle-lp-ark'
import { BaseConfig, Tokens, TokenType } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

interface PendleMarketInfo {
  token: { address: Address; symbol: Tokens }
  marketId: string
  marketName: string
}

interface PendleLPArkUserInput {
  marketSelection: PendleMarketInfo
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  token: { address: Address; symbol: Tokens }
  marketId: string
  marketName: string
  router: Address
  oracle: Address
}

export async function deployPendleLPArk() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting PendleLPArk deployment process...'))

  const userInput = await getUserInput(config)

  if (await confirmDeployment(userInput)) {
    const deployedPendleLPArk = await deployPendleLPArkContract(config, userInput)
    return { ark: deployedPendleLPArk.pendleLPArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<PendleLPArkUserInput> {
  // Extract Pendle markets from the configuration
  const pendleMarkets = []
  if (!config.protocolSpecific.pendle || !config.protocolSpecific.pendle.markets) {
    throw new Error('No Pendle markets found in the configuration.')
  }
  for (const token in config.protocolSpecific.pendle.markets) {
    for (const marketName in config.protocolSpecific.pendle.markets[token as Tokens]
      .marketAddresses) {
      const marketId =
        config.protocolSpecific.pendle.markets[token as TokenType].marketAddresses[marketName]
      pendleMarkets.push({
        title: `${token.toUpperCase()} - ${marketName}`,
        value: {
          token: { symbol: token, address: config.tokens[token as TokenType] },
          marketId,
          marketName,
        },
      })
    }
  }

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
  ])

  // Set the token address based on the selected market
  const selectedMarket = responses.marketSelection
  const tokenAddress = config.tokens[selectedMarket.token as TokenType]
  const routerAddress = config.protocolSpecific.pendle.router
  const oracleAddress = config.protocolSpecific.pendle['lp-oracle']

  const aggregatedData = {
    ...responses,
    token: { address: tokenAddress, symbol: selectedMarket.token },
    marketId: selectedMarket.marketId,
    marketName: selectedMarket.marketName,
    router: routerAddress,
    oracle: oracleAddress,
  }

  return aggregatedData
}

async function confirmDeployment(userInput: PendleLPArkUserInput) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Market ID: ${userInput.marketId}`))
  console.log(kleur.yellow(`Oracle: ${userInput.oracle}`))
  console.log(kleur.yellow(`Router: ${userInput.router}`))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return await continueDeploymentCheck()
}

async function deployPendleLPArkContract(
  config: BaseConfig,
  userInput: PendleLPArkUserInput,
): Promise<PendleLPArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `PendleLp-${userInput.token.symbol}-${userInput.marketName}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  return (await hre.ignition.deploy(createPendleLPArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        market: userInput.marketId,
        oracle: userInput.oracle,
        router: userInput.router,
        arkParams: {
          name: `PendleLp-${userInput.token.symbol}-${userInput.marketName}-${chainId}`,
          details: JSON.stringify({
            protocol: 'Pendle',
            type: 'Lp',
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
          requiresKeeperData: false,
          maxDepositPercentageOfTVL: HUNDRED_PERCENT,
        },
      },
    },
    deploymentId,
  })) as PendleLPArkContracts
}
