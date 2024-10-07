import hre from 'hardhat'
import kleur from 'kleur'
import { BaseConfig } from '../ignition/config/config-types'
import { BuyAndBurnContracts, BuyAndBurnModule } from '../ignition/modules/buy-and-burn'
import { checkExistingContracts } from './helpers/check-existing-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'

export async function deployCore() {
  const config = getConfigByNetwork(hre.network.name)
  const deployedBuyAndBurn = await deployBuyAndBurnContracts(config)
  ModuleLogger.logBuyAndBurn(deployedBuyAndBurn)
  return deployedBuyAndBurn
}

/**
 * Deploys the buyAndBurn contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<CoreContracts>} The deployed buyAndBurn contracts.
 */
async function deployBuyAndBurnContracts(config: BaseConfig): Promise<BuyAndBurnContracts> {
  console.log(kleur.cyan().bold('Deploying Core Contracts...'))

  checkExistingContracts(config, 'buyAndBurn')

  const buyAndBurn = await hre.ignition.deploy(BuyAndBurnModule, {
    parameters: {
      BuyAndBurnModule: {
        summerToken: config.deployedContracts.gov.summerToken,
        protocolAccessManager: config.deployedContracts.core.protocolAccessManager,
        configurationManager: config.deployedContracts.core.configurationManager,
      },
    },
  })

  console.log(kleur.green().bold('All Core Contracts Deployed Successfully!'))

  return buyAndBurn
}

deployCore().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
