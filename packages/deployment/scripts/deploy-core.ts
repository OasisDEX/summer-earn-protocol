import hre from 'hardhat'
import kleur from 'kleur'
import { Address, keccak256, toBytes } from 'viem'
import { CoreContracts, CoreModule } from '../ignition/modules/core'
import { BaseConfig } from '../types/config-types'
import { ADDRESS_ZERO } from './common/constants'
import { checkExistingContracts } from './helpers/check-existing-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { updateIndexJson } from './helpers/update-json'

const ADMIRALS_QUARTERS_ROLE = keccak256(toBytes('ADMIRALS_QUARTERS_ROLE'))

export async function deployCore() {
  const config = getConfigByNetwork(hre.network.name, { common: true, gov: true, core: false })
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
  if (config.deployedContracts.gov.protocolAccessManager.address === ADDRESS_ZERO) {
    throw new Error('ProtocolAccessManager is not deployed')
  }
  if (config.deployedContracts.gov.timelock.address === ADDRESS_ZERO) {
    throw new Error('TimelockController is not deployed')
  }
  if (config.common.layerZero.lzEndpoint === ADDRESS_ZERO) {
    throw new Error('LayerZero is not deployed')
  }
  if (config.common.swapProvider === ADDRESS_ZERO) {
    throw new Error('SwapProvider is not deployed')
  }
  const core = await hre.ignition.deploy(CoreModule, {
    parameters: {
      CoreModule: {
        swapProvider: config.common.swapProvider,
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        treasury: config.deployedContracts.gov.timelock.address,
        lzEndpoint: config.common.layerZero.lzEndpoint,
        weth: config.tokens.weth,
      },
    },
  })

  console.log(kleur.green().bold('All Core Contracts Deployed Successfully!'))

  updateIndexJson('core', hre.network.name, core)

  await setupGovernanceRoles(config)

  return core
}

deployCore().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})

/**
 * @dev Configures the Admirals Quarters role in the ProtocolAccessManager
 *
 * Checks if the Admirals Quarters contract has the ADMIRALS_QUARTERS_ROLE
 * and grants it if not already assigned. This role allows the contract to
 * perform privileged operations within the protocol.
 *
 * @param config - The BaseConfig object containing deployment addresses and settings
 */
async function setupGovernanceRoles(config: BaseConfig) {
  console.log(kleur.cyan().bold('Setting up governance roles...'))
  const publicClient = await hre.viem.getPublicClient()

  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )

  const hasAdmiralsQuartersRole =
    config.deployedContracts.core.admiralsQuarters.address !== ADDRESS_ZERO &&
    (await protocolAccessManager.read.hasRole([
      ADMIRALS_QUARTERS_ROLE,
      config.deployedContracts.core.admiralsQuarters.address,
    ]))
  if (!hasAdmiralsQuartersRole) {
    console.log(
      '[PROTOCOL ACCESS MANAGER] - Granting admirals quarters role to admirals quarters...',
    )
    const hash = await protocolAccessManager.write.grantAdmiralsQuartersRole([
      config.deployedContracts.core.admiralsQuarters.address,
    ])
    await publicClient.waitForTransactionReceipt({ hash })
  }
}
