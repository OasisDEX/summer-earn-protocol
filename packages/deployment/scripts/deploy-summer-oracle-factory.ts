import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createSummerOracleFactoryModule } from '../ignition/modules/summerOracleFactoryModuleFactory'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

export async function deploySummerOracleFactory() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const useBummerConfig = await promptForConfigType()

  const config = getConfigByNetwork(network, { common: true, core: true }, useBummerConfig) as BaseConfig

  if (!(await confirmDeployment(network, config))) {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }

  console.log(kleur.cyan().bold('Deploying SummerOracleFactory...'))

  const chainId = config.common.chainId
  const deploymentId = await handleDeploymentId(chainId)
  const timestampString = new Date().toISOString().replace(/[-:Z.]/g, '')
  const moduleName = `SummerOracleFactoryModule_${timestampString}`
  const Module = createSummerOracleFactoryModule(moduleName)

  const harborCommand = config.deployedContracts.core.harborCommand.address as Address

  const result = await hre.ignition.deploy(Module, {
    parameters: {
      [moduleName]: {
        harborCommand,
      },
    },
    deploymentId,
  })

  console.log(kleur.green().bold('SummerOracleFactory deployed successfully!'))

  const coreContracts = {
    ...config.deployedContracts.core,
    summerOracleFactory: result.summerOracleFactory,
  }
  await updateIndexJson('core', network, coreContracts, useBummerConfig)

  return result
}

async function confirmDeployment(network: string, config: BaseConfig): Promise<boolean> {
  console.log(kleur.yellow(`SummerOracleFactory will be deployed on: ${network}`))
  console.log(kleur.yellow(`Using HarborCommand: ${config.deployedContracts.core.harborCommand.address}`))
  return await continueDeploymentCheck()
}

deploySummerOracleFactory().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})


