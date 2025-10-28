import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address } from 'viem'
import { createFleetProxyModule } from '../ignition/modules/fleet-proxy'
import { BaseConfig } from '../types/config-types'
import {
  createSatellitePhaseConfig,
  getCrossChainConfigStatus,
  loadCrossChainConfig,
  mergeCrossChainConfig,
  saveCrossChainConfig,
} from './lib/config/cross-chain'
import { getAccessManagerAddress, getBridgeRouterAddress } from './lib/config/getters'
import { getConfigByNetwork } from './lib/config/handler'
import {
  printValidationErrors,
  printValidationSuccess,
  validateSatellitePhasePrerequisites,
} from './lib/cross-chain/validation'
import { handleDeploymentId } from './lib/infrastructure/deployment-id-handler'
import { getChainIdByNetwork } from './lib/infrastructure/get-chainid'
import { continueDeploymentCheck } from './lib/infrastructure/prompts'

/**
 * Interface for the FleetProxy deployment parameters
 */
interface FleetProxyParams {
  accessManager: Address
  bridgeRouter: Address
  fleetContract: Address
  sourceChainId: number
  protocol: string
  fleetName: string
  asset: {
    address: string
    symbol: string
  }
}

/**
 * Deploy FleetProxy on the satellite chain
 */
export async function deployFleetProxy() {
  console.log(kleur.green().bold('Starting FleetProxy deployment process...'))
  console.log(kleur.yellow('Note: FleetProxy should be deployed on the satellite chain.'))
  console.log(kleur.cyan('This creates Phase 1 of the cross-chain configuration.'))

  // Ask about using bummer config
  const { useBummerConfig } = await prompts({
    type: 'confirm',
    name: 'useBummerConfig',
    message: 'Do you want to use bummer (test) config?',
    initial: false,
  })

  // Get the current chain configuration
  const config = getConfigByNetwork(
    hre.network.name,
    {
      common: true,
      gov: true,
      core: true,
      bridge: true,
    },
    useBummerConfig,
  ) as BaseConfig

  // Validate prerequisites
  const validation = validateSatellitePhasePrerequisites(config)
  if (!validation.isValid) {
    printValidationErrors(validation.errors, 'satellite')
    throw new Error('Prerequisites not met for satellite phase deployment')
  }
  printValidationSuccess('satellite')

  // Get user input for deployment parameters
  const userInput = await getUserInput(config, useBummerConfig)

  // Ask user to confirm parameters before deploying
  if (await confirmDeployment(userInput, config)) {
    const fleetProxyAddress = await deployFleetProxyContract(userInput, config, userInput.fleetName)

    console.log(kleur.green().bold('FleetProxy successfully deployed at:'), fleetProxyAddress)
    console.log(kleur.green('Deployment recorded in cross-chain configuration.'))

    // Create or update cross-chain config in Phase 1
    await updateCrossChainConfigPhase1(userInput, fleetProxyAddress)

    console.log(kleur.green().bold('✅ Phase 1 (Satellite) Complete!'))
    console.log(kleur.yellow('Next steps:'))
    console.log(kleur.cyan('1. Switch to the source chain network'))
    console.log(kleur.cyan('2. Deploy hub fleet (if not already deployed)'))
    console.log(
      kleur.cyan(
        '3. Deploy CrossChainArk: npx hardhat run scripts/arks/deploy-cross-chain-ark.ts --network <source>',
      ),
    )
    console.log(kleur.cyan('4. Register relationships on both chains'))

    return fleetProxyAddress
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }
}

/**
 * Prompt the user for deployment parameters
 */
async function getUserInput(
  config: BaseConfig,
  useBummerConfig: boolean,
): Promise<FleetProxyParams> {
  // Validate required addresses from config
  const bridgeRouterAddress = getBridgeRouterAddress(config)
  const accessManagerAddress = getAccessManagerAddress(config)

  const currentNetwork = hre.network.name
  const currentChainId = getChainIdByNetwork(currentNetwork)

  // List available fleet deployments
  const deploymentsDir = path.resolve(__dirname, '../../deployments/fleets')
  const deploymentFiles = fs
    .readdirSync(deploymentsDir)
    .filter((file) => file.endsWith('_deployment.json'))

  if (deploymentFiles.length === 0) {
    throw new Error('No fleet deployments found. Deploy a fleet on the source chain first.')
  }

  // Filter deployments based on current chain and bummer config
  const filteredDeploymentFiles = []
  for (const file of deploymentFiles) {
    const deploymentPath = path.join(deploymentsDir, file)
    const deploymentContent = fs.readFileSync(deploymentPath, 'utf8')
    const fleetDeployment = JSON.parse(deploymentContent)

    // Check if deployment is for current chain
    const sourceNetwork = fleetDeployment.network
    const sourceChainId = getChainIdByNetwork(sourceNetwork)

    // Check if fleet name contains "bummer"
    const isBummerFleet = fleetDeployment.fleetName.toLowerCase().includes('bummer')

    // Allow bummer configs to connect to both bummer and prod fleets
    // But restrict prod configs to only prod fleets for safety
    const shouldInclude = sourceChainId === currentChainId && (useBummerConfig || !isBummerFleet)

    if (shouldInclude) {
      filteredDeploymentFiles.push(file)
    }
  }

  if (filteredDeploymentFiles.length === 0) {
    throw new Error(
      `No compatible fleet deployments found for ${currentNetwork}${useBummerConfig ? ' with bummer config' : ''}.`,
    )
  }

  // Allow user to select a deployment file
  const { selectedDeployment } = await prompts({
    type: 'select',
    name: 'selectedDeployment',
    message: 'Select a deployed fleet:',
    choices: filteredDeploymentFiles.map((file) => ({ title: file, value: file })),
  })

  // Load the selected deployment file
  const deploymentPath = path.join(deploymentsDir, selectedDeployment)
  const deploymentContent = fs.readFileSync(deploymentPath, 'utf8')
  const fleetDeployment = JSON.parse(deploymentContent)

  // Extract fleet information
  const fleetName = fleetDeployment.fleetName
  const fleetAddress = fleetDeployment.fleetAddress as Address
  const assetSymbol = fleetDeployment.assetSymbol.toLowerCase()

  // Get the asset address from the config using the symbol
  const assetAddress = config.tokens[assetSymbol as keyof typeof config.tokens] as Address
  if (!assetAddress) {
    throw new Error(`Asset address not found for symbol ${assetSymbol}`)
  }

  const fleetProxyProtocol = 'summerfi'

  return {
    accessManager: accessManagerAddress,
    bridgeRouter: bridgeRouterAddress,
    fleetContract: fleetAddress,
    sourceChainId: currentChainId,
    fleetName,
    protocol: fleetProxyProtocol,
    asset: {
      address: assetAddress,
      symbol: assetSymbol,
    },
  }
}

/**
 * Ask user to confirm deployment parameters
 */
async function confirmDeployment(params: FleetProxyParams, config: BaseConfig): Promise<boolean> {
  console.log(kleur.yellow('\nFleetProxy Deployment Configuration:'))
  console.log(kleur.blue('Fleet Name:'), kleur.cyan(params.fleetName))
  console.log(kleur.blue('Access Manager:'), kleur.cyan(params.accessManager))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(params.bridgeRouter))
  console.log(
    kleur.blue('CrossChain Registry:'),
    kleur.cyan(config.deployedContracts.bridge?.crossChainRegistry.address as string),
  )
  console.log(kleur.blue('Fleet Contract:'), kleur.cyan(params.fleetContract))
  console.log(kleur.blue('Source Chain ID:'), kleur.cyan(params.sourceChainId.toString()))
  console.log(kleur.blue('Protocol:'), kleur.cyan(params.protocol))

  return await continueDeploymentCheck()
}

/**
 * Deploy the FleetProxy contract using Ignition
 */
async function deployFleetProxyContract(
  params: FleetProxyParams,
  config: BaseConfig,
  fleetName: string,
): Promise<Address> {
  const chainId = getChainIdByNetwork(hre.network.name)
  const deploymentId = await handleDeploymentId(chainId)
  const moduleName = `FleetProxy_${fleetName}_${deploymentId}`.replace(/-/g, '_')

  // Get the CrossChainRegistry address from config
  const crossChainRegistryAddress = config.deployedContracts.bridge?.crossChainRegistry.address
  if (!crossChainRegistryAddress) {
    throw new Error(
      'CrossChainRegistry address not found in config. Make sure core contracts are deployed.',
    )
  }

  try {
    // Create the FleetProxy module
    const module = createFleetProxyModule(moduleName)

    // Deploy with all required parameters including CrossChainRegistry
    const result = await hre.ignition.deploy(module, {
      parameters: {
        [moduleName]: {
          accessManager: params.accessManager,
          sourceChainId: params.sourceChainId,
          crossChainRegistry: crossChainRegistryAddress,
          fleetContract: params.fleetContract,
        },
      },
      deploymentId,
    })

    const fleetProxyContract = result as unknown as { fleetProxy: { address: Address } }
    const fleetProxyAddress = fleetProxyContract.fleetProxy.address

    // Cross-chain config will be updated by updateCrossChainConfigPhase1 function

    console.log(
      kleur.yellow('Note: Remember to set the source chain ark address using the governor account'),
    )

    return fleetProxyAddress
  } catch (error) {
    console.error(kleur.red('Error deploying FleetProxy:'), error)
    throw error
  }
}

/**
 * Updates cross-chain config in Phase 1 (satellite deployment)
 */
async function updateCrossChainConfigPhase1(
  userInput: FleetProxyParams,
  fleetProxyAddress: Address,
): Promise<void> {
  const existingConfig = loadCrossChainConfig(userInput.fleetName)

  if (existingConfig) {
    // Update existing config with FleetProxy address
    const updatedConfig = mergeCrossChainConfig(existingConfig, {
      destinations: existingConfig.destinations.map((dest) => ({
        ...dest,
        protocols: dest.protocols.map((protocol) =>
          protocol.protocol === userInput.protocol
            ? { ...protocol, fleetProxyAddress: fleetProxyAddress }
            : protocol,
        ),
      })),
    })

    saveCrossChainConfig(userInput.fleetName, updatedConfig)
    console.log(kleur.green('✓ Updated existing cross-chain configuration'))
  } else {
    // Create new Phase 1 config
    const newConfig = createSatellitePhaseConfig(
      userInput.fleetName,
      userInput.fleetName, // satelliteFleetName same as fleetName for now
      {
        chainId: userInput.sourceChainId,
        name: `chain-${userInput.sourceChainId}`,
        fleetProxyAddress: fleetProxyAddress,
        satelliteFleetAddress: userInput.fleetContract,
        protocol: userInput.protocol,
      },
    )

    saveCrossChainConfig(userInput.fleetName, newConfig)
    console.log(kleur.green('✓ Created new cross-chain configuration (Phase 1)'))
  }

  // Show current status
  const status = getCrossChainConfigStatus(userInput.fleetName)
  console.log(kleur.blue(`Current phase: ${status.phase}`))
  if (status.missingFields.length > 0) {
    console.log(kleur.yellow(`Missing: ${status.missingFields.join(', ')}`))
  }
}

// Direct invocation
if (require.main === module) {
  deployFleetProxy().catch((error) => {
    console.error(kleur.red('Error during FleetProxy deployment:'))
    console.error(error)
    process.exit(1)
  })
}
