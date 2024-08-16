import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import AaveV3ArkModule, { AaveV3ArkContracts } from '../ignition/modules/aavev3-ark'
import { getConfigByNetwork } from './config-handler'
import { ModuleLogger } from './module-logger'

export async function deployAaveV3Ark() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting AaveV3Ark deployment process...'))

  const userInput = await getUserInput()

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedAaveV3Ark = (await hre.ignition.deploy(AaveV3ArkModule, {
      parameters: {
        AaveV3ArkModule: {
          aaveV3Pool: config.aaveV3.pool,
          rewardsController: config.aaveV3.rewards,
          arkParams: {
            name: 'AaveV3Ark',
            accessManager: config.protocolAccessManager,
            configurationManager: config.configurationManager,
            token: userInput.token,
            depositCap: userInput.depositCap,
            maxRebalanceOutflow: userInput.maxRebalanceOutflow,
            maxRebalanceInflow: userInput.maxRebalanceInflow,
          },
        },
      },
    })) as AaveV3ArkContracts

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logAaveV3Ark(deployedAaveV3Ark)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

//0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

async function getUserInput() {
  return await prompts([
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

deployAaveV3Ark().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
