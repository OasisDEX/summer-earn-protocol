import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { BaseConfig } from '../ignition/config/config-types'
import PendlePTArkModule, { PendlePTArkContracts } from '../ignition/modules/arks/pendle-pt-ark'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

export async function deployPendlePTArk() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting PendlePTArk deployment process...'))

  const userInput = await getUserInput()

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedPendlePTArk = await deployPendlePTArkContract(config, userInput)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logPendlePTArk(deployedPendlePTArk)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput() {
  return await prompts([
    {
      type: 'text',
      name: 'market',
      message: 'Enter the Pendle market address:',
    },
    {
      type: 'text',
      name: 'oracle',
      message: 'Enter the Pendle oracle address:',
    },
    {
      type: 'text',
      name: 'router',
      message: 'Enter the Pendle router address:',
    },
    {
      type: 'text',
      name: 'token',
      message: 'Enter the underlying token address:',
    },
    {
      type: 'number',
      name: 'depositCap',
      message: 'Enter the deposit cap:',
    },
    {
      type: 'number',
      name: 'maxRebalanceOutflow',
      message: 'Enter the max rebalance outflow:',
    },
    {
      type: 'number',
      name: 'maxRebalanceInflow',
      message: 'Enter the max rebalance inflow:',
    },
  ])
}

async function confirmDeployment(userInput: any) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Market: ${userInput.market}`))
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
        market: userInput.market,
        oracle: userInput.oracle,
        router: userInput.router,
        arkParams: {
          name: 'PendlePTArk',
          accessManager: config.core.protocolAccessManager,
          configurationManager: config.core.configurationManager,
          token: userInput.token,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
        },
      },
    },
    deploymentId,
  })) as PendlePTArkContracts
}

deployPendlePTArk().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
