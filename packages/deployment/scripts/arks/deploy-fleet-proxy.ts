import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { BaseConfig } from '../../types/config-types'
import { getFleetConfig, loadFleetDeploymentJson } from '../common/fleet-deployment-files-helpers'
import { getConfigByNetwork } from '../helpers/config-handler'
import { saveCrossChainConfig } from '../helpers/cross-chain-config'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

/**
 * Interface for the FleetProxy deployment parameters
 */
interface FleetProxyParams {
  accessManager: Address
  bridgeRouter: Address
  fleetContract: Address
  sourceChainId: number
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
      bridge: true, // Now this is a valid option
    },
    useBummerConfig,
  ) as BaseConfig

  // Get fleet config and check if it's available
  let fleetDefinition
  try {
    fleetDefinition = await getFleetConfig()
  } catch (error) {
    console.error(
      kleur.red('Fleet configuration not found. Please create a fleet configuration first.'),
    )
    throw error
  }

  // Try to load fleet deployment info
  let fleetDeployment
  try {
    fleetDeployment = await loadFleetDeploymentJson(fleetDefinition)
  } catch (error) {
    console.error(
      kleur.red('Fleet deployment not found. Deploy the fleet on the source chain first.'),
    )
    throw error
  }

  // Get user input for deployment parameters
  const userInput = await getUserInput(
    config,
    fleetDefinition.fleetName,
    fleetDeployment?.fleetAddress,
  )

  // Ask user to confirm parameters before deploying
  if (await confirmDeployment(userInput)) {
    const fleetProxyAddress = await deployFleetProxyContract(
      userInput,
      config,
      fleetDefinition.fleetName,
    )

    console.log(kleur.green().bold('FleetProxy successfully deployed at:'), fleetProxyAddress)

    // Custom logging for fleet proxy deployment (since ModuleLogger.logFleetProxy doesn't exist)
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
async function getUserInput(
  config: BaseConfig,
  fleetName: string,
  fleetAddress?: Address,
): Promise<FleetProxyParams> {
  // Use config values when available
  const bridgeRouterAddress = config.deployedContracts.bridge?.bridgeRouter.address as Address
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address as Address

  // Collect source chain ID
  const { sourceChainId } = await prompts({
    type: 'number',
    name: 'sourceChainId',
    message: 'Enter the source chain ID (where the fleet is deployed):',
    validate: (value) => (value > 0 ? true : 'Chain ID must be greater than 0'),
  })

  // Collect fleet address on source chain
  const fleetContractResponse = await prompts({
    type: 'text',
    name: 'fleetContract',
    message: 'Enter the address of the fleet contract on source chain:',
    initial: fleetAddress || '',
    validate: (value) => (/^0x[a-fA-F0-9]{40}$/.test(value) ? true : 'Invalid address format'),
  })

  // Get gas limit for cross-chain operations
  const { gasLimit } = await prompts({
    type: 'number',
    name: 'gasLimit',
    message: 'Enter the gas limit for cross-chain operations:',
    initial: 500000,
    validate: (value) => (value > 0 ? true : 'Gas limit must be greater than 0'),
  })

  return {
    accessManager: accessManagerAddress,
    bridgeRouter: bridgeRouterAddress,
    fleetContract: fleetContractResponse.fleetContract as Address,
    sourceChainId,
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
  console.log(kleur.blue('Access Manager:'), kleur.cyan(params.accessManager))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(params.bridgeRouter))
  console.log(kleur.blue('Fleet Contract:'), kleur.cyan(params.fleetContract))
  console.log(kleur.blue('Source Chain ID:'), kleur.cyan(params.sourceChainId.toString()))
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
  const chainId = await getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const moduleName = `FleetProxy-${deploymentId}`

  // Create and deploy the module
  try {
    // Create the FleetProxy module (need to add this module in the ignition folder)
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

    // Fix the type assertion for fleetProxy address
    // Cast the result to FleetProxyContract to access the address correctly
    const fleetProxyContract = result as unknown as { fleetProxy: { address: Address } }
    const fleetProxyAddress = fleetProxyContract.fleetProxy.address

    // Save the FleetProxy address to cross-chain config
    saveCrossChainConfig(fleetName, {
      fleetName,
      fleetProxyAddress,
      satelliteChainId: chainId,
      sourceChainId: params.sourceChainId,
    })

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
