import fs from 'fs'
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
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

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
  arkParams?: BaseArkParams & {
    bridgeQueue?: Address
    bridgeRouter?: Address
    crossChainRegistry?: Address
    targetChainId?: number
    targetProtocol?: string
    fleetProxyAddress?: Address
    accessManager?: Address
    fleetName?: string
  },
) {
  console.log(kleur.green().bold('Starting CrossChainArk deployment process...'))
  console.log(kleur.yellow('Note: CrossChainArk should be deployed on the source chain.'))
  console.log(kleur.yellow('FleetProxy can be deployed on the satellite chain before or after.'))
  console.log(kleur.yellow('Deployment steps:'))
  console.log(kleur.cyan('1. Deploy bridge components on the source and satellite chains'))
  console.log(kleur.cyan('2. Deploy CrossChainArk on the source chain (this step)'))
  console.log(
    kleur.cyan('3. Deploy FleetProxy on the satellite chain (optional, can be done later)'),
  )
  console.log(kleur.cyan('4. Configure CrossChainArk and FleetProxy to point to each other'))
  console.log(
    kleur.yellow('Note: These components can be deployed in any order and configured later.'),
  )
  console.log(kleur.yellow('Bridge options will be provided by keepers at execution time.'))
  console.log()

  // If fleetName is not provided in arkParams, prompt for it
  let fleetName: string | undefined = arkParams?.fleetName
  if (!fleetName) {
    const { fleetNameInput } = await prompts({
      type: 'text',
      name: 'fleetNameInput',
      message: 'Enter the fleet name:',
      validate: (value) => (value.length > 0 ? true : 'Fleet name is required'),
    })
    fleetName = fleetNameInput
  }

  // Check for existing cross-chain config
  console.log(kleur.blue('Looking for cross-chain config files...'))
  const configDir = path.join(process.cwd(), 'config', 'cross-chain')
  console.log(kleur.blue(`Config directory: ${configDir}`))

  // Ensure the directory exists
  if (!fs.existsSync(configDir)) {
    console.log(kleur.yellow('Cross-chain config directory does not exist'))
    fs.mkdirSync(configDir, { recursive: true })
    console.log(kleur.green('Created cross-chain config directory'))
  }

  // List available config files
  const configFiles = fs.readdirSync(configDir).filter((file) => file.endsWith('.json'))

  if (configFiles.length === 0) {
    console.error(kleur.red('No cross-chain config files found.'))
    console.error(kleur.red(`Expected config files in: ${configDir}`))
    console.error(
      kleur.yellow('The cross-chain config should have been created during FleetProxy deployment.'),
    )
    throw new Error('No cross-chain config files found')
  }

  console.log(kleur.blue('Available cross-chain config files:'))
  configFiles.forEach((file) => {
    console.log(kleur.cyan(`  - ${file}`))
  })

  // Let user select a config file
  let selectedConfigFile: string
  let crossChainConfig: any

  if (arkParams?.targetChainId && arkParams?.targetProtocol) {
    // If specific target chain and protocol are provided, we need to find the matching config file
    const matchingFile = await findMatchingConfigFile(
      configDir,
      configFiles,
      arkParams.targetChainId,
      arkParams.targetProtocol,
    )
    if (!matchingFile) {
      throw new Error(
        `No config file found for chain ${arkParams.targetChainId} and protocol ${arkParams.targetProtocol}`,
      )
    }
    selectedConfigFile = matchingFile
    crossChainConfig = JSON.parse(fs.readFileSync(path.join(configDir, matchingFile), 'utf8'))
  } else {
    // Otherwise let user select from available configs
    const { configFile } = await prompts({
      type: 'select',
      name: 'configFile',
      message: 'Select a cross-chain configuration file:',
      choices: configFiles.map((file) => ({ title: file, value: file })),
    })

    if (!configFile) {
      console.log(kleur.red().bold('No config file selected. Exiting.'))
      return null
    }

    selectedConfigFile = configFile
    const configPath = path.join(configDir, configFile)
    console.log(kleur.blue(`Loading config from: ${configPath}`))
    crossChainConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'))
  }

  console.log(kleur.green(`Loaded cross-chain config: ${selectedConfigFile}`))

  // Get target chain and protocol
  let targetChainId: number
  let targetProtocol: string

  if (arkParams?.targetChainId && arkParams?.targetProtocol) {
    targetChainId = arkParams.targetChainId
    targetProtocol = arkParams.targetProtocol
  } else {
    // Let user choose which destination to deploy to
    const destinations = crossChainConfig.destinations.map((dest: any) => ({
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
    const destination = crossChainConfig.destinations.find((d: any) => d.chainId === targetChainId)
    if (!destination) {
      console.error(kleur.red('Selected destination not found in config.'))
      throw new Error('Invalid destination')
    }

    const protocols = destination.protocols.map((p: any) => ({
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
  const protocolConfig = findProtocolConfigInData(crossChainConfig, targetChainId, targetProtocol)

  const userInput =
    arkParams ||
    (await getUserInput(
      config,
      selectedConfigFile.replace('.json', ''), // Use config file name without extension instead of fleet name
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
  }

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedContracts = await deployCrossChainArkContract(config, userInput, fleetName!)
    // Return in the same format as other arks
    return { ark: deployedContracts.crossChainArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }
}

/**
 * Find a matching config file for the given chain ID and protocol
 */
async function findMatchingConfigFile(
  configDir: string,
  configFiles: string[],
  targetChainId: number,
  targetProtocol: string,
): Promise<string | null> {
  for (const file of configFiles) {
    const configPath = path.join(configDir, file)
    try {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'))
      const matchingDest = config.destinations.find((dest: any) => dest.chainId === targetChainId)
      if (matchingDest) {
        const matchingProtocol = matchingDest.protocols.find(
          (p: any) => p.protocol === targetProtocol,
        )
        if (matchingProtocol) {
          return file
        }
      }
    } catch (error) {
      console.warn(kleur.yellow(`Error reading config file ${file}: ${error}`))
    }
  }
  return null
}

/**
 * Find protocol configuration in the cross-chain config data
 */
function findProtocolConfigInData(crossChainConfig: any, chainId: number, protocol: string) {
  const destination = crossChainConfig.destinations.find((d: any) => d.chainId === chainId)
  if (!destination) return null

  const protocolConfig = destination.protocols.find((p: any) => p.protocol === protocol)
  return protocolConfig
}

/**
 * Prompts the user for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {string} configName - The name of the config file (without extension).
 * @param {number} targetChainId - The target chain ID.
 * @param {string} targetProtocol - The target protocol.
 * @param {object} protocolConfig - Protocol configuration.
 * @returns {Promise<object>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(
  config: BaseConfig,
  configName: string,
  targetChainId: number,
  targetProtocol: string,
  protocolConfig: any,
) {
  // Use bridgeQueue from config
  const bridgeQueueAddress = config.deployedContracts.bridge?.bridgeQueue?.address
  if (!bridgeQueueAddress) {
    console.error(kleur.red('Bridge Queue address not found in config.'))
    console.error(kleur.yellow('Make sure you have the bridge module deployed on this chain.'))
    throw new Error('Bridge Queue address is required')
  }

  const bridgeRouterAddress = config.deployedContracts.bridge?.bridgeRouter?.address
  if (!bridgeRouterAddress) {
    console.error(kleur.red('Bridge Router address not found in config.'))
    console.error(kleur.yellow('Make sure you have the bridge module deployed on this chain.'))
    throw new Error('Bridge Router address is required')
  }

  // Validate CrossChainRegistry is available
  const crossChainRegistryAddress = config.deployedContracts.bridge?.crossChainRegistry?.address
  if (!crossChainRegistryAddress) {
    throw new Error(
      'CrossChainRegistry address not found in config. Make sure bridge contracts are deployed.',
    )
  }

  const fleetProxyAddress = protocolConfig?.fleetProxyAddress as Address | undefined
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address as Address

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
    {
      type: 'text',
      name: 'maxDepositPercentageOfTVL',
      initial: HUNDRED_PERCENT,
      message: 'Enter the max deposit percentage of TVL:',
    },
  ])

  // Get the asset from the cross-chain config or prompt user
  let assetSymbol = protocolConfig?.asset?.symbol
  let assetAddress: Address

  if (!assetSymbol) {
    console.log(
      kleur.yellow(
        'Asset not found in cross-chain config. This is normal if FleetProxy is not deployed yet.',
      ),
    )

    // Prompt user for asset selection
    const tokenChoices = Object.keys(config.tokens).map((token) => ({
      title: token.toUpperCase(),
      value: token,
    }))

    const { selectedAsset } = await prompts({
      type: 'select',
      name: 'selectedAsset',
      message: 'Select the asset for this CrossChainArk:',
      choices: tokenChoices,
    })

    if (!selectedAsset) {
      throw new Error('Asset selection is required')
    }

    assetSymbol = selectedAsset.toUpperCase()
    assetAddress = config.tokens[selectedAsset as keyof typeof config.tokens] as Address
  } else {
    // Get the asset address from the current chain's config
    assetAddress = config.tokens[assetSymbol.toLowerCase() as keyof typeof config.tokens] as Address
    if (!assetAddress) {
      throw new Error(`Asset address not found for symbol ${assetSymbol} on current chain`)
    }
  }

  console.log(kleur.green(`Using asset: ${assetSymbol}`))

  return {
    ...responses,
    token: {
      symbol: assetSymbol,
      address: assetAddress,
    },
    configName,
    bridgeQueue: bridgeQueueAddress,
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
async function confirmDeployment(userInput: any, config: BaseConfig, isAutomated: boolean) {
  if (isAutomated) return true

  console.log(kleur.yellow('\nCrossChainArk Deployment Configuration:'))
  console.log(kleur.blue('Token:'), kleur.cyan(userInput.token.symbol))
  console.log(kleur.blue('Deposit Cap:'), kleur.cyan(userInput.depositCap))
  console.log(kleur.blue('Max Rebalance Outflow:'), kleur.cyan(userInput.maxRebalanceOutflow))
  console.log(kleur.blue('Max Rebalance Inflow:'), kleur.cyan(userInput.maxRebalanceInflow))
  console.log(kleur.blue('Bridge Queue:'), kleur.cyan(userInput.bridgeQueue))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(userInput.bridgeRouter))
  console.log(kleur.blue('CrossChain Registry:'), kleur.cyan(userInput.crossChainRegistry))
  console.log(kleur.blue('Target Chain ID:'), kleur.cyan(userInput.targetChainId))
  console.log(kleur.blue('Target Protocol:'), kleur.cyan(userInput.targetProtocol))
  console.log(kleur.blue('Fleet Proxy:'), kleur.cyan(userInput.fleetProxyAddress))
  console.log(kleur.blue('Access Manager:'), kleur.cyan(userInput.accessManager))

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
  const moduleName = `CrossChainArk_${fleetName}_${deploymentId.replace(/-/g, '_')}`

  const module = createCrossChainArkModule(moduleName)

  // Get the CrossChainRegistry address from config
  const crossChainRegistryAddress = config.deployedContracts.bridge?.crossChainRegistry?.address
  if (!crossChainRegistryAddress) {
    throw new Error(
      'CrossChainRegistry address not found in config. Make sure bridge contracts are deployed.',
    )
  }

  const result = await hre.ignition.deploy(module, {
    parameters: {
      [moduleName]: {
        bridgeQueue: userInput.bridgeQueue,
        bridgeRouter: userInput.bridgeRouter,
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
          maxDepositPercentageOfTVL: userInput.maxDepositPercentageOfTVL,
        },
      },
    },
    deploymentId,
  })

  // Set target proxy if provided
  if (
    userInput.fleetProxyAddress &&
    userInput.fleetProxyAddress !== '0x0000000000000000000000000000000000000000'
  ) {
    console.log(kleur.yellow('Setting target proxy...'))
    const crossChainArkContract = await hre.viem.getContractAt(
      'CrossChainArk' as string,
      result.crossChainArk.address,
    )
    const publicClient = await hre.viem.getPublicClient()

    const proxyHash = await crossChainArkContract.write.setTargetProxy([
      userInput.fleetProxyAddress,
    ])
    console.log(kleur.yellow('Waiting for target proxy transaction to confirm...'))
    await publicClient.waitForTransactionReceipt({ hash: proxyHash })
    console.log(kleur.green('Target proxy set successfully'))
  } else {
    console.log(kleur.yellow('No target proxy provided. You will need to set it later.'))
  }

  return { crossChainArk: result.crossChainArk }
}
