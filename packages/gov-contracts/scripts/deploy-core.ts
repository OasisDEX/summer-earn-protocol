import hre from 'hardhat'
import kleur from 'kleur'
import { BaseConfig } from '../ignition/config/config-types'
import { CoreModule } from '../ignition/modules/core'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'

export async function deployCore() {
  const config = getConfigByNetwork(hre.network.name)
  const deployedCore = await deployCoreContracts(config)
  ModuleLogger.logCore(deployedCore)
  return deployedCore
}

/**
 * Deploys the core contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<CoreContracts>} The deployed core contracts.
 */
async function deployCoreContracts(config: BaseConfig): Promise<CoreContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  console.log(kleur.cyan().bold('Deploying Core Contracts...'))

  const core = await hre.ignition.deploy(CoreModule, {
    parameters: {
      CoreModule: {
        swapProvider: config.core.swapProvider,
        treasury: config.core.treasury,
      },
    },
  })

  console.log(kleur.green().bold('All Core Contracts Deployed Successfully!'))

  return core
}

deployCore().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

export type CoreContracts = {
  protocolAccessManager: { address: string }
  tipJar: { address: string }
  raft: { address: string }
  configurationManager: { address: string }
  harborCommander: { address: string }
  buyAndBurn: { address: string }
  summerGovernor: { address: string }
  admiralsQuarters: { address: string }
}
