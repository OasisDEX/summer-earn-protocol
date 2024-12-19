import hre from 'hardhat'
import kleur from 'kleur'
import { CoreContracts, CoreModule } from '../ignition/modules/core'
import { BaseConfig } from '../types/config-types'
import { checkExistingContracts } from './helpers/check-existing-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { updateIndexJson } from './helpers/update-json'

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
  console.log(kleur.cyan().bold('Deploying Core Contracts...'))

  checkExistingContracts(config, 'core')

  const core = await hre.ignition.deploy(CoreModule, {
    parameters: {
      CoreModule: {
        swapProvider: config.common.swapProvider,
        treasury: config.common.treasury,
        lzEndpoint: config.common.layerZero.lzEndpoint,
        weth: config.tokens.weth,
      },
    },
  })

  console.log(kleur.green().bold('All Core Contracts Deployed Successfully!'))

  updateIndexJson('core', hre.network.name, core)

  return core
}

deployCore().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
