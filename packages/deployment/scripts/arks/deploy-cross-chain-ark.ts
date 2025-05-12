import hre from 'hardhat'
import kleur from 'kleur'
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
import { loadCrossChainConfig, saveCrossChainConfig } from '../helpers/cross-chain-config'
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
    fleetProxyAddress?: Address
    accessManager?: Address
    bridgeOptions?: BridgeOptions
  },
) {
  console.log(kleur.green().bold('Starting CrossChainArk deployment process...'))
  console.log(kleur.yellow('Note: CrossChainArk should be deployed on the source chain.'))
  console.log(kleur.yellow('A FleetProxy should already be deployed on the satellite chain.'))

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

  // Get fleet configuration
  const fleetDefinition = await getFleetConfig()

  // Check for existing cross-chain config with FleetProxy address
  const crossChainConfig = loadCrossChainConfig(fleetDefinition.fleetName)
  if (!crossChainConfig?.fleetProxyAddress) {
    console.error(kleur.red('FleetProxy address not found in cross-chain config.'))
    console.error(
      kleur.red('Please deploy FleetProxy first using the deploy-fleet-proxy.ts script.'),
    )
    throw new Error('FleetProxy must be deployed before CrossChainArk')
  }

  const userInput =
    arkParams || (await getUserInput(config, fleetDefinition.fleetName, crossChainConfig))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedContracts = await deployCrossChainArkContract(
      config,
      userInput,
      fleetDefinition.fleetName,
    )

    // Update cross-chain config with CrossChainArk address
    saveCrossChainConfig(fleetDefinition.fleetName, {
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
 * @param {object} crossChainConfig - Existing cross-chain configuration.
 * @returns {Promise<object>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig, fleetName: string, crossChainConfig: any) {
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
  const bridgeQueueAddress = config.deployedContracts.bridge?.bridgeQueue.address as Address
  const bridgeRouterAddress = config.deployedContracts.bridge?.bridgeRouter.address as Address
  const targetChainId = crossChainConfig.satelliteChainId || Number(config.common.chainId)
  const fleetProxyAddress = crossChainConfig.fleetProxyAddress as Address
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address as Address

  // Prompt only for these fields
  const { gasLimit } = await prompts({
    type: 'number',
    name: 'gasLimit',
    message: 'Enter the gas limit for cross-chain operations:',
    initial: 500000,
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
    fleetProxyAddress,
    accessManager: accessManagerAddress,
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
  const moduleName = `CrossChainArk-${deploymentId}`

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
          name: `CrossChainArk-${userInput.token.symbol}`,
          details: `CrossChainArk for ${userInput.token.symbol}`,
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
