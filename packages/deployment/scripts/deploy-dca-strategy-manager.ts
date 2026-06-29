import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import {
  createDCAStrategyManagerModule,
  DCAStrategyManagerContracts,
} from '../ignition/modules/dca-strategy-manager'
import { BaseConfig } from '../types/config-types'
import { PERMIT2_ADDRESS } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'
import { updateIndexJson } from './helpers/update-json'

async function deployDCAStrategyManager() {
  const network = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(network))

  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Deployments on Tenderly virtual testnets are temporary and will be lost when the session ends.',
  )

  if (isTenderly) {
    const response = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Do you want to continue with deployment on this Tenderly virtual testnet?',
      initial: false,
    })

    if (!response.continue) {
      console.log(kleur.red('Deployment cancelled.'))
      return
    }
  }

  const useBummerConfig = await promptForConfigType()

  const config = getConfigByNetwork(
    network,
    { common: true, core: true, gov: true },
    useBummerConfig,
  ) as BaseConfig

  if (!config.common.ensoRouter) {
    throw new Error(`config.common.ensoRouter is missing for network "${network}"`)
  }

  if (!(await confirmDeployment(network, config))) {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }

  console.log(kleur.cyan().bold('Deploying DCAStrategyManager...'))

  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const versionString = 'v4'
  const moduleName = `DCAStrategyManagerModule_${versionString}`
  const DCAStrategyManagerModule = createDCAStrategyManagerModule(moduleName)

  const result = (await hre.ignition.deploy(DCAStrategyManagerModule, {
    parameters: {
      [moduleName]: {
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        ensoRouter: config.common.ensoRouter,
        harborCommand: config.deployedContracts.core.harborCommand.address,
        permit2: PERMIT2_ADDRESS,
      },
    },
    deploymentId,
  })) as DCAStrategyManagerContracts

  console.log(kleur.green().bold('DCAStrategyManager Deployed Successfully!'))
  console.log(
    kleur.yellow('DCAStrategyManager Address:'),
    kleur.cyan(result.dcaStrategyManager.address),
  )

  updateIndexJson(
    'dca',
    network,
    { dcaStrategyManager: result.dcaStrategyManager },
    useBummerConfig,
  )

  return result
}

async function confirmDeployment(network: string, config: BaseConfig): Promise<boolean> {
  console.log(kleur.yellow(`DCAStrategyManager will be deployed on: ${network}`))
  console.log(kleur.yellow('Constructor arguments:'))
  console.log(
    kleur.yellow('  protocolAccessManager:'),
    kleur.cyan(config.deployedContracts.gov.protocolAccessManager.address),
  )
  console.log(kleur.yellow('  ensoRouter:'), kleur.cyan(config.common.ensoRouter))
  console.log(
    kleur.yellow('  harborCommand:'),
    kleur.cyan(config.deployedContracts.core.harborCommand.address),
  )
  console.log(kleur.yellow('  permit2:'), kleur.cyan(PERMIT2_ADDRESS))
  return await continueDeploymentCheck()
}

deployDCAStrategyManager().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
