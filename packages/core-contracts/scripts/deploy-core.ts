import hre from 'hardhat'
import kleur from 'kleur'
import { BaseConfig } from '../ignition/config/config-types'
import {
  AccessModule,
  AdmiralsModule,
  BuyAndBurnModule,
  CommandModule,
  ConfigModule,
  GovernanceModule,
  LibrariesModule,
  RaftModule,
  TokenModule,
  TreasuryModule,
} from '../ignition/modules/core'
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

  const deployModule = async (name: string, module: any, params: any = {}) => {
    console.log(kleur.yellow().bold(`Deploying ${name}...`))
    const result = await hre.ignition.deploy(module, {
      parameters: params,
      deploymentId,
    })
    console.log(kleur.green().bold(`${name} deployed successfully!`))
    return result
  }

  const token = await deployModule('Token', TokenModule)
  const libraries = await deployModule('Libraries', LibrariesModule)
  const access = await deployModule('Access', AccessModule)
  const treasury = await deployModule('Treasury', TreasuryModule, {
    treasury: config.core.treasury,
  })
  const raft = await deployModule('Raft', RaftModule)
  const configManager = await deployModule('Config', ConfigModule)
  const command = await deployModule('Command', CommandModule)
  const admirals = await deployModule('Admirals', AdmiralsModule, {
    swapProvider: config.core.swapProvider,
  })
  const governance = await deployModule('Governance', GovernanceModule)
  const buyAndBurn = await deployModule('BuyAndBurn', BuyAndBurnModule, {
    treasury: config.core.treasury,
  })

  console.log(kleur.green().bold('All Core Contracts Deployed Successfully!'))

  return {
    protocolAccessManager: access.protocolAccessManager,
    tipJar: treasury.tipJar,
    raft: raft.raft,
    configurationManager: configManager.configurationManager,
    harborCommander: command.harborCommander,
    buyAndBurn: buyAndBurn.buyAndBurn,
    summerGovernor: governance.summerGovernor,
    admiralsQuarters: admirals.admiralsQuarters,
  } as CoreContracts
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
