import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import PendlePTArkModule, { PendlePTArkContracts } from '../../ignition/modules/arks/pendle-pt-ark'
import { BaseConfig, Tokens, TokenType } from '../../types/config-types'
import { MAX_UINT256_STRING } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { ModuleLogger } from '../helpers/module-logger'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

export async function deployPendlePTArk() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting PendlePTArk deployment process...'))

  const userInput = await getUserInput(config)

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedPendlePTArk = await deployPendlePTArkContract(config, userInput)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logPendlePTArk(deployedPendlePTArk)

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
    for (const marketName in config.protocolSpecific.pendle.markets[token as Tokens]) {
      const marketId = config.protocolSpecific.pendle.markets[token as TokenType][marketName]
      pendleMarkets.push({
        title: `${token.toUpperCase()} - ${marketName}`,
        value: { token, marketId },
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
    token: tokenAddress,
    marketId: selectedMarket.marketId,
    router: routerAddress,
    oracle: oracleAddress,
  }

  return aggregatedData
}

async function confirmDeployment(userInput: any) {
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

async function deployPendlePTArkContract(
  config: BaseConfig,
  userInput: any,
): Promise<PendlePTArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  return (await hre.ignition.deploy(PendlePTArkModule, {
    parameters: {
      PendlePTArkModule: {
        market: userInput.marketId,
        oracle: userInput.oracle,
        router: userInput.router,
        arkParams: {
          name: `PendlePt-${userInput.token}-${userInput.marketId}-${chainId}`,
          accessManager: config.deployedContracts.core.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
          token: userInput.token,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
        },
      },
    },
    deploymentId,
  })) as PendlePTArkContracts
}
