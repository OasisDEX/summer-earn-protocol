import hre from 'hardhat'
import kleur from 'kleur'
import { Address, keccak256, toBytes } from 'viem'
import { CoreContracts, createCoreModule } from '../ignition/modules/core'
import { BaseConfig } from '../types/config-types'
import { checkExistingContracts } from './helpers/check-existing-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'
import { validateAddress } from './helpers/validation'

const ADMIRALS_QUARTERS_ROLE = keccak256(toBytes('ADMIRALS_QUARTERS_ROLE'))

export async function deployCore() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  // Ask about using bummer config at the beginning
  const useBummerConfig = await promptForConfigType()

  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: false },
    useBummerConfig,
  ) as BaseConfig
  const deployedCore = await deployCoreContracts(config, useBummerConfig)
  ModuleLogger.logCore(deployedCore)
  return deployedCore
}

/**
 * Deploys the core contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<CoreContracts>} The deployed core contracts.
 */
async function deployCoreContracts(
  config: BaseConfig,
  useBummerConfig: boolean,
): Promise<CoreContracts> {
  console.log(kleur.cyan().bold('Deploying Core Contracts...'))

  checkExistingContracts(config, 'core')
  const protocolAccessManager = validateAddress(
    config.deployedContracts.gov.protocolAccessManager.address,
    'gov.protocolAccessManager',
  )
  const timelock = validateAddress(config.deployedContracts.gov.timelock.address, 'gov.timelock')
  const swapProvider = validateAddress(config.common.swapProvider, 'common.swapProvider')
  const wrappedNative = validateAddress(config.tokens.wrappedNative, 'tokens.wrappedNative')

  // Only add 'staging' prefix if bummer, no prefix for prod (for compatibility)
  const moduleName = useBummerConfig ? 'staging_CoreModule' : 'CoreModule'
  const coreModule = createCoreModule(moduleName)
  const core = await hre.ignition.deploy(coreModule, {
    parameters: {
      [moduleName]: {
        swapProvider: swapProvider,
        protocolAccessManager: protocolAccessManager,
        treasury: timelock,
        wrappedNative: wrappedNative,
      },
    },
  })

  console.log(kleur.green().bold('All Core Contracts Deployed Successfully!'))

  updateIndexJson('core', hre.network.name, core, useBummerConfig)

  const updatedConfig = getConfigByNetwork(
    hre.network.name,
    {
      common: false,
      gov: true,
      core: true,
    },
    useBummerConfig,
  ) as BaseConfig

  await setupGovernanceRoles(updatedConfig)

  return core
}

// When script is run directly
if (require.main === module) {
  deployCore().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}

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
    validateAddress(
      config.deployedContracts.core.admiralsQuarters.address,
      'core.admiralsQuarters',
    ) &&
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
