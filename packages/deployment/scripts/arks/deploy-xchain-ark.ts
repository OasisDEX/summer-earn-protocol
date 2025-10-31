import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  CrossChainArkContracts,
  createCrossChainArkModule,
} from '../../ignition/modules/arks/cross-chain-ark'
import { BaseConfig } from '../../types/config-types'
import {
  CrossChainConfig,
  ensureConfigFleetName,
  ensureCrossChainConfigDirectory,
  getCrossChainConfigStatus,
  loadCrossChainConfig,
  mergeCrossChainConfig,
  resolveTargetDestination,
  saveCrossChainConfig,
  selectCrossChainConfig,
  validateCrossChainConfigPhase,
} from '../lib/config/cross-chain'
import {
  getCrossChainAssetForProtocol,
  getFleetProxyAddress,
} from '../lib/config/cross-chain-getters'
import {
  getAccessManagerAddress,
  getBridgeRouterAddress,
  getCrossChainRegistryAddress,
} from '../lib/config/getters'
import {
  printValidationErrors,
  printValidationSuccess,
  validateHubPhasePrerequisites,
} from '../lib/cross-chain/validation'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../lib/infrastructure/constants'
import { handleDeploymentId } from '../lib/infrastructure/deployment-id-handler'
import { getChainId } from '../lib/infrastructure/get-chainid'
import { continueDeploymentCheck } from '../lib/infrastructure/prompts'
import { CrossChainArkDeploymentParams, CrossChainArkUserInput } from './ark-types'

// Export the type
export { CrossChainArkContracts } from '../../ignition/modules/arks/cross-chain-ark'

/**
 * Main function to deploy a CrossChainArk and FleetProxy.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for both networks
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying both contracts
 * - Logging deployment results
 */
export async function deployCrossChainArk(
  config: BaseConfig,
  arkParams?: CrossChainArkDeploymentParams,
): Promise<{ ark: { address: string } } | null> {
  console.log(kleur.green().bold('Starting CrossChainArk deployment process...'))
  console.log(kleur.yellow('Note: CrossChainArk should be deployed on the source chain.'))
  console.log(kleur.cyan('This creates Phase 2 of the cross-chain configuration.'))
  console.log()

  const validation = validateHubPhasePrerequisites(config)
  if (!validation.isValid) {
    printValidationErrors(validation.errors, 'hub')
    throw new Error('Prerequisites not met for hub phase deployment')
  }
  printValidationSuccess('hub')

  const fleetName = await resolveFleetName(arkParams)

  const configDir = path.join(process.cwd(), 'config', 'cross-chain')
  const configFiles = ensureCrossChainConfigDirectory(configDir)

  const configSelection = await selectCrossChainConfig(configDir, configFiles, {
    targetChainId: arkParams?.targetChainId,
    targetProtocol: arkParams?.targetProtocol,
  })
  if (!configSelection) {
    return null
  }

  const { selectedConfigFile, crossChainConfig } = configSelection
  console.log(kleur.green(`Loaded cross-chain config: ${selectedConfigFile}`))

  const configFleetName = ensureConfigFleetName(crossChainConfig, fleetName)

  const targetSelection = await resolveTargetDestination(crossChainConfig, {
    targetChainId: arkParams?.targetChainId,
    targetProtocol: arkParams?.targetProtocol,
  })
  if (!targetSelection) {
    return null
  }

  const { targetChainId, targetProtocol } = targetSelection

  const userInput = await resolveDeploymentInput(
    config,
    selectedConfigFile,
    targetChainId,
    targetProtocol,
    crossChainConfig,
    arkParams,
  )

  if (!(await confirmDeployment(userInput, config, arkParams != undefined))) {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }

  const deployedContracts = await deployCrossChainArkContract(
    config,
    userInput,
    fleetName,
    configFleetName,
  )

  return { ark: deployedContracts.crossChainArk }
}

async function resolveFleetName(arkParams?: CrossChainArkDeploymentParams): Promise<string> {
  if (arkParams?.fleetName) {
    return arkParams.fleetName
  }

  const { fleetNameInput } = await prompts({
    type: 'text',
    name: 'fleetNameInput',
    message: 'Enter the fleet name:',
    validate: (value) => (value.length > 0 ? true : 'Fleet name is required'),
  })

  return fleetNameInput
}

async function resolveDeploymentInput(
  config: BaseConfig,
  selectedConfigFile: string,
  targetChainId: number,
  targetProtocol: string,
  crossChainConfig: CrossChainConfig,
  arkParams?: CrossChainArkDeploymentParams,
): Promise<CrossChainArkUserInput> {
  if (arkParams) {
    return populateAutomatedDefaults(config, selectedConfigFile, arkParams)
  }

  return getUserInput(
    config,
    selectedConfigFile.replace('.json', ''),
    targetChainId,
    targetProtocol,
    crossChainConfig,
  )
}

function populateAutomatedDefaults(
  config: BaseConfig,
  selectedConfigFile: string,
  arkParams: CrossChainArkDeploymentParams,
): CrossChainArkUserInput {
  return {
    ...arkParams,
    configName: arkParams.configName || selectedConfigFile.replace('.json', ''),
    bridgeRouter: arkParams.bridgeRouter || getBridgeRouterAddress(config),
    crossChainRegistry: arkParams.crossChainRegistry || getCrossChainRegistryAddress(config),
    accessManager: arkParams.accessManager || getAccessManagerAddress(config),
  }
}

/**
 * Prompts the user for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {string} configName - The name of the config file (without extension).
 * @param {number} targetChainId - The target chain ID.
 * @param {string} targetProtocol - The target protocol.
 * @returns {Promise<object>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(
  config: BaseConfig,
  configName: string,
  targetChainId: number,
  targetProtocol: string,
  crossChainConfig: CrossChainConfig,
) {
  const bridgeRouterAddress = getBridgeRouterAddress(config)

  // Validate CrossChainRegistry is available
  const crossChainRegistryAddress = getCrossChainRegistryAddress(config)

  // FleetProxy must exist (enforces Phase 1 complete before Phase 2)
  const fleetProxyAddress = getFleetProxyAddress(crossChainConfig, targetChainId, targetProtocol)
  const accessManagerAddress = getAccessManagerAddress(config)

  // Get other parameters from user
  const responses = await prompts([
    {
      type: 'text',
      name: 'depositCap',
      initial: MAX_UINT256_STRING,
      message: 'Enter the deposit cap:',
    },
    {
      type: 'text',
      name: 'maxRebalanceOutflow',
      initial: MAX_UINT256_STRING,
      message: 'Enter the max rebalance outflow:',
    },
    {
      type: 'text',
      name: 'maxRebalanceInflow',
      initial: MAX_UINT256_STRING,
      message: 'Enter the max rebalance inflow:',
    },
  ])

  // Get the asset from the cross-chain config
  const assetInfo = getCrossChainAssetForProtocol(crossChainConfig, targetChainId, targetProtocol)
  const assetSymbol = assetInfo.symbol
  const assetAddress = assetInfo.address

  console.log(kleur.green(`Using asset from config: ${assetSymbol}`))

  return {
    ...responses,
    token: {
      symbol: assetSymbol,
      address: assetAddress,
    },
    configName,
    bridgeRouter: bridgeRouterAddress,
    crossChainRegistry: crossChainRegistryAddress,
    targetChainId,
    targetProtocol,
    fleetProxyAddress,
    accessManager: accessManagerAddress,
  }
}

/**
 * Confirms the deployment with the user
 * @param {object} userInput - The user's input for deployment parameters
 * @param {BaseConfig} config - The configuration object for the current network
 * @param {boolean} isAutomated - Whether this is an automated deployment
 * @returns {Promise<boolean>} Whether the user confirmed the deployment
 */
async function confirmDeployment(
  userInput: CrossChainArkUserInput,
  config: BaseConfig,
  isAutomated: boolean,
) {
  if (isAutomated) return true

  console.log(kleur.yellow('\nCrossChainArk Deployment Configuration:'))
  console.log(kleur.blue('Token:'), kleur.cyan(userInput.token.symbol))
  console.log(kleur.blue('Deposit Cap:'), kleur.cyan(userInput.depositCap))
  console.log(kleur.blue('Max Rebalance Outflow:'), kleur.cyan(userInput.maxRebalanceOutflow))
  console.log(kleur.blue('Max Rebalance Inflow:'), kleur.cyan(userInput.maxRebalanceInflow))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(userInput.bridgeRouter!))
  console.log(kleur.blue('CrossChain Registry:'), kleur.cyan(userInput.crossChainRegistry!))
  console.log(kleur.blue('Target Chain ID:'), kleur.cyan(userInput.targetChainId))
  console.log(kleur.blue('Target Protocol:'), kleur.cyan(userInput.targetProtocol))
  console.log(kleur.blue('Fleet Proxy:'), kleur.cyan(userInput.fleetProxyAddress))
  console.log(kleur.blue('Access Manager:'), kleur.cyan(userInput.accessManager!))

  return await continueDeploymentCheck()
}

/**
 * Deploys the CrossChainArk contract
 * @param {BaseConfig} config - The configuration object for the current network
 * @param {object} userInput - The user's input for deployment parameters
 * @param {string} fleetName - The name of the fleet (for module naming)
 * @param {string} configFleetName - The fleet name from the config file (for config operations)
 * @returns {Promise<CrossChainArkContracts>} The deployed contracts
 */
async function deployCrossChainArkContract(
  config: BaseConfig,
  userInput: CrossChainArkUserInput,
  fleetName: string,
  configFleetName: string,
): Promise<CrossChainArkContracts> {
  const chainId = await getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const moduleName = `CrossChainArk_${fleetName}_${deploymentId.replace(/-/g, '_')}`

  const module = createCrossChainArkModule(moduleName)

  // Get the CrossChainRegistry address from config
  const crossChainRegistryAddress = getCrossChainRegistryAddress(config)

  const result = await hre.ignition.deploy(module, {
    parameters: {
      [moduleName]: {
        bridgeRouter: userInput.bridgeRouter!,
        crossChainRegistry: crossChainRegistryAddress,
        targetChainId: userInput.targetChainId,
        arkParams: {
          name: `CrossChainArk-${userInput.token.symbol}-${userInput.targetProtocol}`,
          details: `CrossChainArk for ${userInput.token.symbol} using ${userInput.targetProtocol} on chain ${userInput.targetChainId}`,
          accessManager: config.deployedContracts.gov.protocolAccessManager.address,
          configurationManager: config.deployedContracts.core.configurationManager.address,
          asset: userInput.token.address,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
          maxDepositPercentageOfTVL: HUNDRED_PERCENT,
        },
      },
    },
    deploymentId,
  })

  // Update cross-chain config in Phase 2 - use configFleetName for config operations
  await updateCrossChainConfigPhase2(
    configFleetName,
    result.crossChainArk.address,
    userInput,
    fleetName,
  )

  return { crossChainArk: result.crossChainArk }
}

/**
 * Updates cross-chain config in Phase 2 (hub deployment)
 */
async function updateCrossChainConfigPhase2(
  configFleetName: string,
  crossChainArkAddress: Address,
  userInput: CrossChainArkUserInput,
  hubFleetName?: string,
): Promise<void> {
  const existingConfig = loadCrossChainConfig(configFleetName)

  if (!existingConfig) {
    console.log(kleur.yellow('No existing cross-chain config found. Creating new config...'))
    // This shouldn't happen in normal flow, but handle gracefully
    return
  }

  // Validate that we have a Phase 1 config
  const satelliteValidation = validateCrossChainConfigPhase(existingConfig, 'satellite')
  if (!satelliteValidation.isValid) {
    console.log(kleur.red('Cross-chain config is not in valid satellite phase. Cannot proceed.'))
    console.log(kleur.red('Please deploy FleetProxy first.'))
    return
  }

  // Update config with hub information
  const updatedConfig = mergeCrossChainConfig(existingConfig, {
    sourceChainId: userInput.sourceChainId || (await getChainId()),
    hubFleetName: userInput.hubFleetName || hubFleetName || configFleetName,
    destinations: existingConfig.destinations.map((dest) => ({
      ...dest,
      protocols: dest.protocols.map((protocol) =>
        protocol.protocol === userInput.targetProtocol
          ? { ...protocol, crossChainArkAddress: crossChainArkAddress }
          : protocol,
      ),
    })),
  })

  saveCrossChainConfig(configFleetName, updatedConfig)
  console.log(kleur.green('✓ Updated cross-chain configuration (Phase 2)'))

  // Show current status
  const status = getCrossChainConfigStatus(configFleetName)
  console.log(kleur.blue(`Current phase: ${status.phase}`))
  if (status.missingFields.length > 0) {
    console.log(kleur.yellow(`Missing: ${status.missingFields.join(', ')}`))
  }

  console.log(kleur.green().bold('✅ Phase 2 (Hub) Complete!'))
  console.log(kleur.yellow('Next steps:'))
  console.log(
    kleur.cyan(
      '1. Register adapter peers: npx hardhat run scripts/cross-chain/register-ark-fleet.ts --network <chain>',
    ),
  )
  console.log(
    kleur.cyan(
      '2. Verify setup: npx hardhat run scripts/cross-chain/verify-setup.ts --network <chain>',
    ),
  )
}
