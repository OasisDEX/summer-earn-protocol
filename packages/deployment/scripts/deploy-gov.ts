import hre from 'hardhat'
import kleur from 'kleur'
import { BaseConfig } from '../ignition/config/config-types'
import { GovContracts, GovModule } from '../ignition/modules/gov'
import { checkExistingContracts } from './helpers/check-existing-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { updateIndexJson } from './helpers/update-json'

export async function deployGov() {
  const config = getConfigByNetwork(hre.network.name)
  const deployedGov = await deployGovContracts(config)
  ModuleLogger.logGov(deployedGov)
  return deployedGov
}

/**
 * Deploys the gov contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<GovContracts>} The deployed gov contracts.
 */
async function deployGovContracts(config: BaseConfig): Promise<GovContracts> {
  console.log(kleur.cyan().bold('Deploying Core Contracts...'))

  checkExistingContracts(config, 'gov')

  const gov = await hre.ignition.deploy(GovModule, {
    parameters: {
      GovModule: {
        lzEndpoint: config.common.lzEndpoint,
      },
    },
  })

  updateIndexJson('gov', hre.network.name, gov)

  console.log(kleur.green().bold('All Core Contracts Deployed Successfully!'))

  return gov
}

deployGov().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
