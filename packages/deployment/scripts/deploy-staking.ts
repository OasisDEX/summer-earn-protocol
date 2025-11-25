import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import { Address, encodeFunctionData, getAddress, parseAbi } from 'viem'
import { StakingContracts, createStakingModule } from '../ignition/modules/staking'
import { BaseConfig } from '../types/config-types'
import { ADDRESS_ZERO, HUB_CHAIN_NAME } from './common/constants'
import { checkExistingContracts } from './helpers/check-existing-contracts'
import { getConfigByNetwork } from './helpers/config-handler'
import { ModuleLogger } from './helpers/module-logger'
import { promptForConfigType } from './helpers/prompt-helpers'
import { updateIndexJson } from './helpers/update-json'
import { isSatelliteChain } from './helpers/get-hub-chain'
import { GOVERNOR_ROLE } from './common/constants'
import { validateAddress } from './helpers/validation'

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

  // Only add 'staging' prefix if bummer, no prefix for prod (for compatibility)
  const moduleName = useBummerConfig ? 'staging_StakingModule' : 'StakingModule'
  const stakingModule = createStakingModule(moduleName)

  const staking = await hre.ignition.deploy(stakingModule, {
    parameters: {
      [moduleName]: {
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

  // Create Safe transaction proposal to add staking modules
  await createStakingSafeProposal(updatedConfig, staking)

  return staking
}

/**
 * Creates a Safe transaction proposal to add staking modules to StakedSummerToken
 * This is required because the deployer typically doesn't have the permissions to call addStakingModule directly.
 */
async function createStakingSafeProposal(config: BaseConfig, stakingContracts: StakingContracts) {
  console.log(kleur.cyan().bold('\nCreating Safe transaction proposal for Staking Modules...'))

  // Ensure we are on the Hub chain
  if (hre.network.name !== HUB_CHAIN_NAME) {
    console.log(kleur.yellow(`Skipping proposal creation: Not on Hub Chain (${HUB_CHAIN_NAME})`))
    return
  }

  const foundationMultisig = process.env.FOUNDATION_MULTISIG_ADDRESS
  if (!foundationMultisig) {
    console.log(kleur.yellow('Skipping Safe proposal: FOUNDATION_MULTISIG_ADDRESS not set'))
    return
  }

  const multisigAddress = validateAddress(foundationMultisig, 'FOUNDATION_MULTISIG_ADDRESS')
  const protocolAccessManagerAddress = validateAddress(
    config.deployedContracts.gov.protocolAccessManager.address,
    'protocolAccessManager.address',
  )
  const stakedSummerTokenAddress = validateAddress(
    stakingContracts.summerGovernanceToken.address,
    'summerGovernanceToken.address',
  )
  const summerStakingAddress = validateAddress(
    stakingContracts.summerStaking.address,
    'summerStaking.address',
  )
  const escrowAddress = validateAddress(
    stakingContracts.summerVestingWalletsEscrow.address,
    'summerVestingWalletsEscrow.address',
  )

  // Check if the multisig has the necessary permissions (Governor rights)
  const publicClient = await hre.viem.getPublicClient()

  // Using ProtocolAccessManager to check roles
  // We check for GOVERNOR_ROLE as a proxy for high-level permissions

  const hasRole = await publicClient.readContract({
    address: protocolAccessManagerAddress,
    abi: parseAbi(['function hasRole(bytes32 role, address account) external view returns (bool)']),
    functionName: 'hasRole',
    args: [GOVERNOR_ROLE, multisigAddress],
  })

  if (!hasRole) {
    throw new Error(
      `FOUNDATION_MULTISIG_ADDRESS (${multisigAddress}) does not have DEFAULT_ADMIN_ROLE on ProtocolAccessManager. Cannot proceed with Safe proposal generation.`,
    )
  }

  console.log(kleur.green(`✓ FOUNDATION_MULTISIG_ADDRESS has required permissions`))

  // ABI for addStakingModule
  const addStakingModuleAbi = parseAbi(['function addStakingModule(address module) external'])

  const transactions = []

  // Transaction 1: Add SummerStaking
  transactions.push({
    to: stakedSummerTokenAddress,
    value: '0',
    data: encodeFunctionData({
      abi: addStakingModuleAbi,
      functionName: 'addStakingModule',
      args: [summerStakingAddress],
    }),
    contractMethod: {
      inputs: [{ name: 'module', type: 'address' }],
      name: 'addStakingModule',
      payable: false,
    },
    contractInputsValues: {
      module: summerStakingAddress,
    },
  })

  // Transaction 2: Add SummerVestingWalletsEscrow
  transactions.push({
    to: stakedSummerTokenAddress,
    value: '0',
    data: encodeFunctionData({
      abi: addStakingModuleAbi,
      functionName: 'addStakingModule',
      args: [escrowAddress],
    }),
    contractMethod: {
      inputs: [{ name: 'module', type: 'address' }],
      name: 'addStakingModule',
      payable: false,
    },
    contractInputsValues: {
      module: escrowAddress,
    },
  })

  // Create Safe transaction JSON
  const chainId = (await publicClient.getChainId()).toString()
  const timestamp = Date.now()

  const safeTransactionsJson = {
    version: '1.0',
    chainId: chainId,
    createdAt: timestamp,
    meta: {
      name: 'Add Staking Modules',
      description:
        'Add SummerStaking and SummerVestingWalletsEscrow as staking modules to StakedSummerToken',
      txBuilderVersion: '1.16.3',
      createdFromSafeAddress: multisigAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions,
  }

  // Ensure proposals directory exists
  const proposalsDir = path.join(process.cwd(), 'proposals')
  if (!fs.existsSync(proposalsDir)) {
    fs.mkdirSync(proposalsDir, { recursive: true })
  }

  const fileName = `add_staking_modules_safe_tx_${timestamp}.json`
  const outputPath = path.join(proposalsDir, fileName)

  fs.writeFileSync(outputPath, JSON.stringify(safeTransactionsJson, null, 2))

  console.log(kleur.green(`✅ Saved Safe transaction proposal to ${outputPath}`))
  console.log(kleur.yellow('Please execute this transaction via the Safe Transaction Builder.'))
}

// When script is run directly
if (require.main === module) {
  deployStaking(false).catch((error) => {
    console.error(kleur.red().bold('An error occurred:'), error)
    process.exit(1)
  })
}
