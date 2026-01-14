import hre from 'hardhat'
import kleur from 'kleur'
import { Address, keccak256, toBytes } from 'viem'
import {
  createTimelockGuardFactoryModule,
  TimelockGuardFactoryContracts,
} from '../ignition/modules/timelock-guard-factory'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'

/**
 * Salt for CREATE2 deployment strategy
 * This ensures the TimelockGuardFactory has the same address across all chains
 * Generated from keccak256 hash of the string "timelockGuardSummer"
 */
const CREATE2_SALT = keccak256(toBytes('timelockGuardSummer'))

/**
 * Deploys the TimelockGuardFactory contract using CREATE2 strategy for deterministic addresses
 * @returns {Promise<TimelockGuardFactoryContracts>} The deployed TimelockGuardFactory contract
 */
export async function deployTimelockGuardFactory() {
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  // Ask about using bummer config at the beginning
  const useBummerConfig = await promptForConfigType()

  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: false, core: false },
    useBummerConfig,
  ) as BaseConfig

  const deployedFactory = await deployTimelockGuardFactoryContracts(config, useBummerConfig)
  ModuleLogger.logTimelockGuardFactory(deployedFactory)
  return deployedFactory
}

/**
 * Deploys the TimelockGuardFactory contract using Hardhat Ignition with CREATE2 strategy
 * @param {BaseConfig} config - The configuration object for the current network
 * @param {boolean} useBummerConfig - Whether to use the bummer (test) configuration
 * @returns {Promise<TimelockGuardFactoryContracts>} The deployed TimelockGuardFactory contract
 */
async function deployTimelockGuardFactoryContracts(
  config: BaseConfig,
  useBummerConfig: boolean,
): Promise<TimelockGuardFactoryContracts> {
  console.log(kleur.cyan().bold('Deploying TimelockGuardFactory Contract...'))

  // Check if timelockGuardFactory already exists in gov section
  const existingFactory = config.deployedContracts.gov.timelockGuardFactory
  if (
    existingFactory?.address &&
    existingFactory.address !== '0x0000000000000000000000000000000000000000'
  ) {
    throw new Error(
      `TimelockGuardFactory is already deployed at ${existingFactory.address}. Cannot redeploy.`,
    )
  }

  // Only add 'staging' prefix if bummer, no prefix for prod (for compatibility)
  const moduleName = useBummerConfig
    ? 'staging_TimelockGuardFactoryModule'
    : 'TimelockGuardFactoryModule'
  const timelockGuardFactoryModule = createTimelockGuardFactoryModule(moduleName)

  console.log(
    kleur.yellow(
      `Using CREATE2 strategy with salt: ${CREATE2_SALT} for deterministic address across chains`,
    ),
  )

  // Deploy using CREATE2 strategy for deterministic addresses across chains
  const deploymentResult = await hre.ignition.deploy(timelockGuardFactoryModule, {
    strategy: 'create2',
    strategyConfig: {
      salt: CREATE2_SALT,
    },
  })

  const timelockGuardFactory = deploymentResult as TimelockGuardFactoryContracts
  const factoryAddress = (timelockGuardFactory.timelockGuardFactory as { address: string }).address

  console.log(kleur.green().bold('TimelockGuardFactory Deployed Successfully!'))
  console.log(kleur.cyan(`Address: ${factoryAddress}`))

  // Update config with timelockGuardFactory under gov section
  updateIndexJson('gov', hre.network.name, timelockGuardFactory, useBummerConfig)

  return timelockGuardFactory
}

// When script is run directly
if (require.main === module) {
  deployTimelockGuardFactory().catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
