import hre from 'hardhat'
import kleur from 'kleur'

import { GovContracts, GovModule } from '../../ignition/modules/gov'
import { BaseConfig } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { ModuleLogger } from '../helpers/module-logger'
import { updateIndexJson } from '../helpers/update-json'

export async function deployGov() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))
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
  console.log(kleur.cyan().bold('Deploying Gov Contracts...'))

  const initialSupply = getInitialSupply(config)
  console.log(kleur.blue('Initial Supply:'), kleur.cyan(`${initialSupply} SUMMER`))

  if (config.common.layerZero.lzEndpoint === ADDRESS_ZERO) {
    throw new Error('LayerZero is not set up correctly')
  }
  // Add peer configuration prompt
  console.log('Deploying Gov Module...')
  const gov = await hre.ignition.deploy(GovModule, {
    parameters: {
      GovModule: {
        lzEndpoint: config.common.layerZero.lzEndpoint,
        initialSupply,
      },
    },
  })

  console.log('Updating index.json...')
  updateIndexJson('gov', hre.network.name, gov)

  console.log(kleur.green().bold('All Gov Contracts Deployed Successfully!'))

  return gov
}

/**
 * Retrieves the initial supply of tokens from the configuration.
 *
 * @param config - The configuration object for the current network.
 * @returns The initial supply of tokens as a bigint, scaled to 18 decimal places.
 */
function getInitialSupply(config: BaseConfig): bigint {
  return BigInt(config.common.initialSupply) * 10n ** 18n
}

if (require.main === module) {
  deployGov().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
