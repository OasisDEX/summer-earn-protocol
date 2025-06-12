import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address } from 'viem'
import { createFleetProxyModule } from '../ignition/modules/fleet-proxy'
import { BaseConfig } from '../types/config-types'
import { getConfigByNetwork } from './helpers/config-handler'
import { loadCrossChainConfig, saveCrossChainConfig } from './helpers/cross-chain-config'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainIdByNetwork } from './helpers/get-chainid'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

/**
 * Interface for the FleetProxy deployment parameters
 */
interface FleetProxyParams {
  accessManager: Address
  bridgeRouter: Address
  bridgeQueue: Address
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

  // Get user input for deployment parameters
  const userInput = await getUserInput(config, useBummerConfig)

  // Ask user to confirm parameters before deploying
  if (await confirmDeployment(userInput, config)) {
    const fleetProxyAddress = await deployFleetProxyContract(userInput, config, userInput.fleetName)

    console.log(kleur.green().bold('FleetProxy successfully deployed at:'), fleetProxyAddress)
    console.log(kleur.green('Deployment recorded in cross-chain configuration.'))

    // Optional step: Ask if CrossChain Ark has been deployed and save its address
    await promptForCrossChainArkAddress(
      userInput.fleetName,
      userInput.protocol,
      userInput.sourceChainId,
    )

    console.log(
      kleur.green('Note: Deploy CrossChainArk on the source chain if not already deployed.'),
    )
    console.log(kleur.green('Cross-chain connectivity can be configured at any time.'))
    console.log(kleur.green('Bridge options will be provided by keepers at execution time.'))

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
  const bridgeRouterAddress = config.deployedContracts.bridge?.bridgeRouter.address as Address
  const bridgeQueueAddress = config.deployedContracts.bridge?.bridgeQueue.address as Address
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address as Address
  const crossChainRegistryAddress = config.deployedContracts.bridge?.crossChainRegistry.address

  if (!bridgeRouterAddress) {
    throw new Error(
      'Bridge Router address not found in config. Make sure bridge contracts are deployed.',
    )
  }
  if (!bridgeQueueAddress) {
    throw new Error(
      'Bridge Queue address not found in config. Make sure bridge contracts are deployed.',
    )
  }
  if (!crossChainRegistryAddress) {
    throw new Error(
      'CrossChainRegistry address not found in config. Make sure core contracts are deployed.',
    )
  }

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
  const sourceNetwork = fleetDeployment.network
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
    bridgeQueue: bridgeQueueAddress,
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
  console.log(kleur.blue('Bridge Queue:'), kleur.cyan(params.bridgeQueue))
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
          bridgeRouter: params.bridgeRouter,
          bridgeQueue: params.bridgeQueue,
          crossChainRegistry: crossChainRegistryAddress,
          fleetContract: params.fleetContract,
        },
      },
      deploymentId,
    })

    const fleetProxyContract = result as unknown as { fleetProxy: { address: Address } }
    const fleetProxyAddress = fleetProxyContract.fleetProxy.address

    // Save the FleetProxy address to cross-chain config
    saveCrossChainConfig(fleetName, {
      chainId: chainId,
      protocol: params.protocol,
      fleetProxyAddress: fleetProxyAddress,
    })

    // Make sure the source chain ID is updated in the config
    const crossChainConfig = loadCrossChainConfig(fleetName)
    if (crossChainConfig && crossChainConfig.sourceChainId === 0) {
      saveCrossChainConfig(fleetName, {
        sourceChainId: params.sourceChainId,
      })
    }

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
 * Optional step to prompt user for CrossChain Ark address and save it to config
 */
async function promptForCrossChainArkAddress(
  fleetName: string,
  protocol: string,
  sourceChainId: number,
): Promise<void> {
  console.log(kleur.yellow('\n--- Optional: CrossChain Ark Configuration ---'))

  const { hasCrossChainArk } = await prompts({
    type: 'confirm',
    name: 'hasCrossChainArk',
    message: 'Has the corresponding CrossChain Ark been deployed on the source chain?',
    initial: false,
  })

  if (hasCrossChainArk) {
    const { crossChainArkAddress } = await prompts({
      type: 'text',
      name: 'crossChainArkAddress',
      message: 'Enter the CrossChain Ark address:',
      validate: (value: string) => {
        if (!value || value.trim() === '') {
          return 'CrossChain Ark address is required'
        }
        if (!value.startsWith('0x') || value.length !== 42) {
          return 'Please enter a valid Ethereum address (0x...)'
        }
        return true
      },
    })

    if (crossChainArkAddress) {
      // Save the CrossChain Ark address to the cross-chain config
      saveCrossChainConfig(fleetName, {
        chainId: sourceChainId,
        protocol,
        crossChainArkAddress: crossChainArkAddress.trim(),
      })

      console.log(
        kleur.green(`✓ CrossChain Ark address saved to configuration: ${crossChainArkAddress}`),
      )
      console.log(kleur.green('✓ Cross-chain configuration is now complete!'))
    }
  } else {
    console.log(kleur.yellow('CrossChain Ark address can be added later when deployed.'))
    console.log(kleur.yellow('Use the cross-chain config helper to update the configuration.'))
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
