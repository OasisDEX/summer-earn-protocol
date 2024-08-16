import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import CompoundV3ArkModule, { CompoundV3ArkContracts } from '../ignition/modules/compoundv3-ark'
import { getConfigByNetwork } from './config-handler'
import { ModuleLogger } from './module-logger'

export async function deployCompoundV3Ark() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting CompoundV3Ark deployment process...'))

  const userInput = await getUserInput()

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedCompoundV3Ark = (await hre.ignition.deploy(CompoundV3ArkModule, {
      parameters: {
        CompoundV3ArkModule: {
          compoundV3Pool: userInput.compoundV3Pool,
          compoundV3Rewards: userInput.compoundV3Rewards,
          arkParams: {
            name: 'CompoundV3Ark',
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: userInput.token,
            maxAllocation: userInput.depositCap,
          },
        },
      },
    })) as CompoundV3ArkContracts

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logCompoundV3Ark(deployedCompoundV3Ark)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput() {
  return await prompts([
    {
      type: 'text',
      name: 'compoundV3Pool',
      message: 'Enter the Compound V3 Pool address:',
    },
    {
      type: 'text',
      name: 'compoundV3Rewards',
      message: 'Enter the Compound V3 Rewards address:',
    },
    {
      type: 'text',
      name: 'token',
      message: 'Enter the token address:',
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
  console.log(kleur.yellow(`Compound V3 Pool: ${userInput.compoundV3Pool}`))
  console.log(kleur.yellow(`Compound V3 Rewards: ${userInput.compoundV3Rewards}`))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: 'Do you want to continue with the deployment?',
  })

  return confirmed
}

deployCompoundV3Ark().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
