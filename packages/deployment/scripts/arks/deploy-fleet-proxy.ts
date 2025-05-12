import fs from 'fs'
import hre from 'hardhat'
import kleur from 'kleur'
import path from 'path'
import prompts from 'prompts'
import { Address } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getConfigByNetwork } from '../helpers/config-handler'
import { loadCrossChainConfig, saveCrossChainConfig } from '../helpers/cross-chain-config'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainIdByNetwork } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

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
  bridgeOptions: {
    specifiedAdapter: Address
    adapterParams: {
      gasLimit: number
      calldataSize: number
      msgValue: number
      options: string
    }
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
  const userInput = await getUserInput(config)

  // Ask user to confirm parameters before deploying
  if (await confirmDeployment(userInput)) {
    const fleetProxyAddress = await deployFleetProxyContract(userInput, config, userInput.fleetName)

    console.log(kleur.green().bold('FleetProxy successfully deployed at:'), fleetProxyAddress)
    console.log(kleur.green('Deployment recorded in cross-chain configuration.'))
    console.log(kleur.green('Next step: Deploy CrossChainArk on the source chain.'))

    return fleetProxyAddress
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }
}

/**
 * Prompt the user for deployment parameters
 */
async function getUserInput(config: BaseConfig): Promise<FleetProxyParams> {
  // Use config values when available
  const bridgeRouterAddress = config.deployedContracts.bridge?.bridgeRouter.address as Address
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address as Address

  // List available fleet deployments
  const deploymentsDir = path.resolve(__dirname, '../../deployments/fleets')
  const deploymentFiles = fs
    .readdirSync(deploymentsDir)
    .filter((file) => file.endsWith('_deployment.json'))

  if (deploymentFiles.length === 0) {
    throw new Error('No fleet deployments found. Deploy a fleet on the source chain first.')
  }

  // Allow user to select a deployment file
  const { selectedDeployment } = await prompts({
    type: 'select',
    name: 'selectedDeployment',
    message: 'Select a deployed fleet:',
    choices: deploymentFiles.map((file) => ({ title: file, value: file })),
  })

  // Load the selected deployment file
  const deploymentPath = path.join(deploymentsDir, selectedDeployment)
  const deploymentContent = fs.readFileSync(deploymentPath, 'utf8')
  const fleetDeployment = JSON.parse(deploymentContent)

  // Extract fleet information
  const fleetName = fleetDeployment.fleetName
  const fleetAddress = fleetDeployment.fleetAddress as Address
  const sourceNetwork = fleetDeployment.network

  const sourceChainId = getChainIdByNetwork(sourceNetwork)
  const currentChainId = getChainIdByNetwork(hre.network.name)

  // Validate that source chain is different from current chain
  if (sourceChainId === currentChainId) {
    throw new Error(
      `Invalid deployment: Source chain (${sourceNetwork}) must be different from the current chain (${hre.network.name}). FleetProxy should be deployed on a satellite chain, not the source chain.`,
    )
  }

  // Get gas limit for cross-chain operations
  const { gasLimit } = await prompts({
    type: 'number',
    name: 'gasLimit',
    message: 'Enter the gas limit for cross-chain operations:',
    initial: 500000,
    validate: (value) => (value > 0 ? true : 'Gas limit must be greater than 0'),
  })

  const fleetProxyProtocol = 'summerfi'

  return {
    accessManager: accessManagerAddress,
    bridgeRouter: bridgeRouterAddress,
    fleetContract: fleetAddress,
    sourceChainId,
    fleetName,
    protocol: fleetProxyProtocol,
    bridgeOptions: {
      specifiedAdapter: '0x0000000000000000000000000000000000000000' as Address,
      adapterParams: {
        gasLimit,
        calldataSize: 0,
        msgValue: 0,
        options: '',
      },
    },
  }
}

/**
 * Ask user to confirm deployment parameters
 */
async function confirmDeployment(params: FleetProxyParams): Promise<boolean> {
  console.log(kleur.yellow('\nFleetProxy Deployment Configuration:'))
  console.log(kleur.blue('Fleet Name:'), kleur.cyan(params.fleetName))
  console.log(kleur.blue('Access Manager:'), kleur.cyan(params.accessManager))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(params.bridgeRouter))
  console.log(kleur.blue('Fleet Contract:'), kleur.cyan(params.fleetContract))
  console.log(kleur.blue('Source Chain ID:'), kleur.cyan(params.sourceChainId.toString()))
  console.log(kleur.blue('Protocol:'), kleur.cyan(params.protocol))
  console.log(
    kleur.blue('Gas Limit:'),
    kleur.cyan(params.bridgeOptions.adapterParams.gasLimit.toString()),
  )

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
  // params.
  const chainId = getChainIdByNetwork(hre.network.name)
  const deploymentId = await handleDeploymentId(chainId)
  const moduleName = `FleetProxy-${deploymentId}`

  // Create and deploy the module
  try {
    // Create the FleetProxy module
    const createModule = require('../../ignition/modules/arks/fleet-proxy').createFleetProxyModule
    const module = createModule(moduleName)

    const result = await hre.ignition.deploy(module, {
      parameters: {
        [moduleName]: {
          accessManager: params.accessManager,
          bridgeRouter: params.bridgeRouter,
          fleetContract: params.fleetContract,
          bridgeOptions: {
            specifiedAdapter: params.bridgeOptions.specifiedAdapter,
            adapterParams: params.bridgeOptions.adapterParams,
          },
          // The CrossChainArk address will be updated later
          sourceChainArk: '0x0000000000000000000000000000000000000000' as Address,
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

    return fleetProxyAddress
  } catch (error) {
    console.error(kleur.red('Error deploying FleetProxy:'), error)
    throw error
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
