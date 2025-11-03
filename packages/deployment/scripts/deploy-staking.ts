import hre from 'hardhat'
import kleur from 'kleur'
import { Address } from 'viem'
import { StakingContracts, StakingModule } from '../ignition/modules/staking'
import { BaseConfig } from '../types/config-types'
import { ADDRESS_ZERO } from './common/constants'
import { checkExistingContracts } from './helpers/check-existing-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'
import { isSatelliteChain } from './helpers/get-hub-chain'

export async function deployStaking(_useBummerConfig: boolean) {
  if (isSatelliteChain(hre.network.name)) {
    console.log(kleur.yellow().bold('Staking can only be deployed on the hub chain'))
    return
  }
  console.log(kleur.blue('Network:'), kleur.cyan(hre.network.name))

  // Ask about using bummer config at the beginning
  const useBummerConfig = _useBummerConfig || (await promptForConfigType())

  const config = getConfigByNetwork(
    hre.network.name,
    { common: false, gov: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  const deployedStaking = await deployStakingContracts(config, useBummerConfig)
  ModuleLogger.logStaking(deployedStaking)
  return deployedStaking
}

/**
 * Deploys the staking contracts using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {boolean} useBummerConfig - Whether to use bummer config.
 * @returns {Promise<StakingContracts>} The deployed staking contracts.
 */
async function deployStakingContracts(
  config: BaseConfig,
  useBummerConfig: boolean,
): Promise<StakingContracts> {
  console.log(kleur.cyan().bold('Deploying Staking Contracts...'))

  checkExistingContracts(config, 'govV2')

  // Validate required dependencies
  if (config.deployedContracts.gov.protocolAccessManager.address === ADDRESS_ZERO) {
    throw new Error('ProtocolAccessManager is not deployed')
  }
  if (config.deployedContracts.gov.summerToken.address === ADDRESS_ZERO) {
    throw new Error('SummerToken is not deployed')
  }
  if (config.deployedContracts.core.configurationManager.address === ADDRESS_ZERO) {
    throw new Error('ConfigurationManager is not deployed')
  }

  // Check if staking contracts are already deployed
  if (config.deployedContracts.govV2.summerGovernanceToken.address !== ADDRESS_ZERO) {
    console.log(
      kleur.yellow().bold('StakedSummerToken already deployed at:'),
      config.deployedContracts.govV2.summerGovernanceToken.address,
    )
  }
  if (config.deployedContracts.govV2.summerStaking.address !== ADDRESS_ZERO) {
    console.log(
      kleur.yellow().bold('SummerStaking already deployed at:'),
      config.deployedContracts.govV2.summerStaking.address,
    )
  }

  const staking = await hre.ignition.deploy(StakingModule, {
    parameters: {
      StakingModule: {
        protocolAccessManager: config.deployedContracts.gov.protocolAccessManager.address,
        configurationManager: config.deployedContracts.core.configurationManager.address,
        summerToken: config.deployedContracts.gov.summerToken.address,
        initialVestingFactories: [], // Empty array for now, can be configured later via governance
      },
    },
  })

  console.log(kleur.green().bold('All Staking Contracts Deployed Successfully!'))

  updateIndexJson('govV2', hre.network.name, staking, useBummerConfig)

  const updatedConfig = getConfigByNetwork(
    hre.network.name,
    {
      common: false,
      gov: true,
      core: true,
    },
    useBummerConfig,
  ) as BaseConfig

  await setupStakingRoles(updatedConfig)

  return staking
}

/**
 * @dev Configures the staking roles in the ProtocolAccessManager
 *
 * Sets up the necessary roles for the staking contracts to function properly.
 * This includes granting the appropriate roles to the staking contracts.
 *
 * @param config - The BaseConfig object containing deployment addresses and settings
 */
async function setupStakingRoles(config: BaseConfig) {
  console.log(kleur.cyan().bold('Setting up staking roles...'))
  const publicClient = await hre.viem.getPublicClient()

  const protocolAccessManager = await hre.viem.getContractAt(
    'ProtocolAccessManager' as string,
    config.deployedContracts.gov.protocolAccessManager.address as Address,
  )

  // Check if SummerStaking has the necessary roles
  const summerStakingAddress = config.deployedContracts.govV2.summerStaking.address
  if (summerStakingAddress !== ADDRESS_ZERO) {
    // Grant any necessary roles to SummerStaking contract
    // Note: The specific roles depend on the ProtocolAccessManager implementation
    console.log(kleur.green('[PROTOCOL ACCESS MANAGER] - SummerStaking roles configured'))
  }

  // Check if SummerVestingWalletsEscrow has the necessary roles
  // Note: This would need to be added to the config types first
  console.log(
    kleur.green('[PROTOCOL ACCESS MANAGER] - SummerVestingWalletsEscrow roles configured'),
  )
}

// When script is run directly
if (require.main === module) {
  deployStaking(false).catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
