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
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { getConfigByNetwork } from '../helpers/config-handler'
import {
  findProtocolConfig,
  loadCrossChainConfig,
  saveCrossChainConfig,
} from '../helpers/cross-chain-config'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

interface BridgeOptions {
  specifiedAdapter: Address
  adapterParams: {
    gasLimit: number
    calldataSize: number
    msgValue: number
    options: string
  }
}

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
  config?: BaseConfig,
  arkParams?: BaseArkParams & {
    bridgeQueue?: Address
    bridgeRouter?: Address
    targetChainId?: number
    targetProtocol?: string
    fleetProxyAddress?: Address
    accessManager?: Address
    bridgeOptions?: BridgeOptions
  },
  fleetConfig?: any,
) {
  console.log(kleur.green().bold('Starting CrossChainArk deployment process...'))
  console.log(kleur.yellow('Note: CrossChainArk should be deployed on the source chain.'))
  console.log(kleur.yellow('A FleetProxy should already be deployed on the satellite chain.'))
  console.log(kleur.yellow('Required deployment steps:'))
  console.log(
    kleur.cyan('1. Deploy bridge components on the source chain (if not already deployed)'),
  )
  console.log(
    kleur.cyan('2. Deploy FleetProxy on the satellite chain (creates cross-chain config file)'),
  )
  console.log(kleur.cyan('3. Deploy CrossChainArk on the source chain (this step)'))
  console.log(kleur.cyan('4. Update FleetProxy with CrossChainArk address (final step)'))
  console.log()

  // If no config was provided, ask for bummer config and get the config
  if (!config) {
    const { useBummerConfig } = await prompts({
      type: 'confirm',
      name: 'useBummerConfig',
      message: 'Do you want to use bummer (test) config?',
      initial: false,
    })

    config = getConfigByNetwork(
      hre.network.name,
      {
        common: true,
        gov: true,
        core: true,
        bridge: true,
      },
      useBummerConfig,
    ) as BaseConfig
  }

  // Get fleet configuration if not provided
  const fleetDefinition = fleetConfig || (await getFleetConfig())

  // Check for existing cross-chain config
  console.log(kleur.blue('Looking for cross-chain config file...'))
  const fs = require('fs')
  const configDir = path.join(process.cwd(), 'packages', 'deployment', 'config', 'cross-chain')
  console.log(kleur.blue(`Config directory: ${configDir}`))

  if (fs.existsSync(configDir)) {
    console.log(kleur.blue('Available cross-chain config files:'))
    const files = fs.readdirSync(configDir)
    if (files.length === 0) {
      console.log(kleur.yellow('  No config files found'))
    } else {
      files.forEach((file: string) => {
        console.log(kleur.cyan(`  - ${file}`))
      })
    }
  } else {
    console.log(kleur.yellow('Cross-chain config directory does not exist'))
    fs.mkdirSync(configDir, { recursive: true })
    console.log(kleur.green('Created cross-chain config directory'))
  }

  const crossChainConfigPath = path.join(configDir, `${fleetDefinition.fleetName}.json`)
  console.log(kleur.blue(`Expected config file: ${crossChainConfigPath}`))
  console.log(kleur.blue(`File exists: ${fs.existsSync(crossChainConfigPath) ? 'Yes' : 'No'}`))

  const crossChainConfig = loadCrossChainConfig(fleetDefinition.fleetName)

  if (!crossChainConfig) {
    console.error(kleur.red('Cross-chain config not found for this fleet.'))
    console.error(
      kleur.red(
        `Expected config at: ${path.join(process.cwd(), 'packages', 'deployment', 'config', 'cross-chain', `${fleetDefinition.fleetName}.json`)}`,
      ),
    )
    console.error(
      kleur.yellow('The cross-chain config should have been created during FleetProxy deployment.'),
    )
    console.error(
      kleur.yellow(
        'Please make sure you have deployed the FleetProxy on the satellite chain first.',
      ),
    )
    throw new Error('Cross-chain config not found')
  }

  // Get target chain and protocol
  let targetChainId: number
  let targetProtocol: string

  if (arkParams?.targetChainId && arkParams?.targetProtocol) {
    targetChainId = arkParams.targetChainId
    targetProtocol = arkParams.targetProtocol
  } else {
    // Let user choose which destination to deploy to
    const destinations = crossChainConfig.destinations.map((dest) => ({
      title: `${dest.name} (Chain ID: ${dest.chainId})`,
      value: dest.chainId,
    }))

    if (destinations.length === 0) {
      console.error(kleur.red('No destinations defined in the cross-chain config.'))
      throw new Error('No destinations defined')
    }

    const { selectedChainId } = await prompts({
      type: 'select',
      name: 'selectedChainId',
      message: 'Select target chain:',
      choices: destinations,
    })

    if (!selectedChainId) {
      console.log(kleur.red().bold('No chain selected. Exiting.'))
      return null
    }

    targetChainId = selectedChainId

    // Now select the protocol
    const destination = crossChainConfig.destinations.find((d) => d.chainId === targetChainId)
    if (!destination) {
      console.error(kleur.red('Selected destination not found in config.'))
      throw new Error('Invalid destination')
    }

    const protocols = destination.protocols.map((p) => ({
      title: p.protocol,
      value: p.protocol,
    }))

    const { selectedProtocol } = await prompts({
      type: 'select',
      name: 'selectedProtocol',
      message: 'Select protocol:',
      choices: protocols,
    })

    if (!selectedProtocol) {
      console.log(kleur.red().bold('No protocol selected. Exiting.'))
      return null
    }

    targetProtocol = selectedProtocol
  }

  // Find the protocol configuration
  const protocolConfig = findProtocolConfig(crossChainConfig, targetChainId, targetProtocol)

  if (!protocolConfig || !protocolConfig.fleetProxyAddress) {
    console.error(
      kleur.red(
        `FleetProxy address not found for chain ${targetChainId} and protocol ${targetProtocol}.`,
      ),
    )
    console.error(
      kleur.red('Please deploy FleetProxy first using the deploy-fleet-proxy.ts script.'),
    )
    throw new Error('FleetProxy must be deployed before CrossChainArk')
  }

  console.log('config [debug]', config)

  const userInput =
    arkParams ||
    (await getUserInput(
      config,
      fleetDefinition.fleetName,
      targetChainId,
      targetProtocol,
      protocolConfig,
    ))

  // Validate required parameters if arkParams was provided
  if (arkParams) {
    if (!arkParams.bridgeQueue) {
      console.error(kleur.red('Bridge Queue address is required in arkParams.'))
      throw new Error('Bridge Queue address is required')
    }
    if (!arkParams.bridgeRouter) {
      console.error(kleur.red('Bridge Router address is required in arkParams.'))
      throw new Error('Bridge Router address is required')
    }
    if (!arkParams.fleetProxyAddress) {
      console.error(kleur.red('Fleet Proxy address is required in arkParams.'))
      throw new Error('Fleet Proxy address is required')
    }
  }

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedContracts = await deployCrossChainArkContract(
      config,
      userInput,
      fleetDefinition.fleetName,
    )

    // Update cross-chain config with CrossChainArk address
    saveCrossChainConfig(fleetDefinition.fleetName, {
      chainId: targetChainId,
      protocol: targetProtocol,
      crossChainArkAddress: deployedContracts.crossChainArk.address as Address,
    })

    console.log(
      kleur.green().bold('CrossChainArk successfully deployed at:'),
      deployedContracts.crossChainArk.address,
    )
    console.log(
      kleur.yellow(
        'IMPORTANT: You need to run the update-fleet-proxy.ts script on the satellite chain',
      ),
    )
    console.log(kleur.yellow('to update the FleetProxy with the CrossChainArk address.'))

    return deployedContracts
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null as any
  }
}

/**
 * Prompts the user for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {string} fleetName - The name of the fleet.
 * @param {number} targetChainId - The target chain ID.
 * @param {string} targetProtocol - The target protocol.
 * @param {object} protocolConfig - Protocol configuration.
 * @returns {Promise<object>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(
  config: BaseConfig,
  fleetName: string,
  targetChainId: number,
  targetProtocol: string,
  protocolConfig: any,
) {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as keyof typeof config.tokens]
    if (tokenAddress) {
      tokens.push({
        title: tokenSymbol,
        value: { address: tokenAddress, symbol: tokenSymbol },
      })
    }
  }

  // Use config values for these fields
  const bridgeQueueAddress = config.deployedContracts.bridge?.bridgeQueue?.address
  if (!bridgeQueueAddress) {
    console.error(kleur.red('Bridge Queue address not found in config.'))
    console.error(kleur.yellow('Make sure you have the bridge module deployed on this chain.'))
    console.error(
      kleur.yellow(
        'You can deploy it with: npx hardhat run scripts/bridge/deploy-bridge.ts --network <network>',
      ),
    )
    throw new Error('Bridge Queue address is required')
  }

  const bridgeRouterAddress = config.deployedContracts.bridge?.bridgeRouter?.address
  if (!bridgeRouterAddress) {
    console.error(kleur.red('Bridge Router address not found in config.'))
    console.error(kleur.yellow('Make sure you have the bridge module deployed on this chain.'))
    console.error(
      kleur.yellow(
        'You can deploy it with: npx hardhat run scripts/bridge/deploy-bridge.ts --network <network>',
      ),
    )
    throw new Error('Bridge Router address is required')
  }

  const fleetProxyAddress = protocolConfig.fleetProxyAddress as Address
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address as Address
  const { bridgeOptions } = protocolConfig

  // Default gas limit or get from existing config
  const initialGasLimit = bridgeOptions?.adapterParams?.gasLimit || 500000

  // Prompt only for these fields
  const { gasLimit } = await prompts({
    type: 'number',
    name: 'gasLimit',
    message: 'Enter the gas limit for cross-chain operations:',
    initial: initialGasLimit,
  })

  const responses = await prompts([
    {
      type: 'select',
      name: 'token',
      message: 'Select token:',
      choices: tokens,
    },
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

  return {
    ...responses,
    fleetName,
    bridgeQueue: bridgeQueueAddress,
    bridgeRouter: bridgeRouterAddress,
    targetChainId,
    targetProtocol,
    fleetProxyAddress,
    accessManager: accessManagerAddress,
    bridgeOptions: {
      specifiedAdapter:
        bridgeOptions?.specifiedAdapter ||
        ('0x0000000000000000000000000000000000000000' as Address),
      adapterParams: {
        gasLimit,
        calldataSize: bridgeOptions?.adapterParams?.calldataSize || 0,
        msgValue: bridgeOptions?.adapterParams?.msgValue || 0,
        options: bridgeOptions?.adapterParams?.options || '0x',
      },
    },
  }
}

/**
 * Confirms the deployment with the user
 * @param {object} userInput - The user's input for deployment parameters
 * @param {BaseConfig} config - The configuration object for the current network
 * @param {boolean} isAutomated - Whether this is an automated deployment
 * @returns {Promise<boolean>} Whether the user confirmed the deployment
 */
async function confirmDeployment(userInput: any, config: BaseConfig, isAutomated: boolean) {
  if (isAutomated) return true

  console.log(kleur.yellow('\nCrossChainArk Deployment Configuration:'))
  console.log(kleur.blue('Token:'), kleur.cyan(userInput.token.symbol))
  console.log(kleur.blue('Deposit Cap:'), kleur.cyan(userInput.depositCap))
  console.log(kleur.blue('Max Rebalance Outflow:'), kleur.cyan(userInput.maxRebalanceOutflow))
  console.log(kleur.blue('Max Rebalance Inflow:'), kleur.cyan(userInput.maxRebalanceInflow))
  console.log(kleur.blue('Bridge Queue:'), kleur.cyan(userInput.bridgeQueue))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(userInput.bridgeRouter))
  console.log(kleur.blue('Target Chain ID:'), kleur.cyan(userInput.targetChainId))
  console.log(kleur.blue('Target Protocol:'), kleur.cyan(userInput.targetProtocol))
  console.log(kleur.blue('Fleet Proxy:'), kleur.cyan(userInput.fleetProxyAddress))
  console.log(kleur.blue('Access Manager:'), kleur.cyan(userInput.accessManager))
  console.log(kleur.blue('Gas Limit:'), kleur.cyan(userInput.bridgeOptions.adapterParams.gasLimit))

  return await continueDeploymentCheck()
}

/**
 * Deploys the CrossChainArk contract
 * @param {BaseConfig} config - The configuration object for the current network
 * @param {object} userInput - The user's input for deployment parameters
 * @param {string} fleetName - The name of the fleet
 * @returns {Promise<CrossChainArkContracts>} The deployed contracts
 */
async function deployCrossChainArkContract(
  config: BaseConfig,
  userInput: any,
  fleetName: string,
): Promise<CrossChainArkContracts> {
  const chainId = await getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const moduleName = `CrossChainArk_${deploymentId.replace(/-/g, '_')}`

  // Log important parameters to help with debugging
  console.log(kleur.yellow('\nDeployment parameters:'))
  console.log(kleur.blue('Module Name:'), kleur.cyan(moduleName))
  console.log(kleur.blue('Bridge Queue:'), kleur.cyan(userInput.bridgeQueue))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(userInput.bridgeRouter))
  console.log(kleur.blue('Target Chain ID:'), kleur.cyan(userInput.targetChainId))
  console.log(kleur.blue('Fleet Proxy:'), kleur.cyan(userInput.fleetProxyAddress))

  const module = createCrossChainArkModule(moduleName)
  const result = await hre.ignition.deploy(module, {
    parameters: {
      [moduleName]: {
        bridgeQueue: userInput.bridgeQueue,
        bridgeRouter: userInput.bridgeRouter,
        targetChainId: userInput.targetChainId,
        fleetProxy: userInput.fleetProxyAddress,
        bridgeOptions: {
          specifiedAdapter: userInput.bridgeOptions.specifiedAdapter,
          adapterParams: {
            gasLimit: userInput.bridgeOptions.adapterParams.gasLimit,
            calldataSize: userInput.bridgeOptions.adapterParams.calldataSize,
            msgValue: userInput.bridgeOptions.adapterParams.msgValue,
            options: userInput.bridgeOptions.adapterParams.options,
          },
        },
        arkParams: {
          name: `CrossChainArk-${userInput.token.symbol}-${userInput.targetProtocol}`,
          details: `CrossChainArk for ${userInput.token.symbol} using ${userInput.targetProtocol} on chain ${userInput.targetChainId}`,
          accessManager: config.deployedContracts.core.configurationManager.address,
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

  return result as CrossChainArkContracts
}

// Direct invocation
if (require.main === module) {
  deployCrossChainArk(undefined).catch((error) => {
    console.error(kleur.red('Error during CrossChainArk deployment:'))
    console.error(error)
    process.exit(1)
  })
}
