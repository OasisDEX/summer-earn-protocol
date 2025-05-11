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
    bridgeQueue: Address
    bridgeRouter: Address
    targetChainId: number
    fleetContract: Address
    accessManager: Address
    bridgeOptions: BridgeOptions
  },
) {
  console.log(kleur.green().bold('Starting CrossChainArk and FleetProxy deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedContracts = await deployCrossChainArkContract(config, userInput)
    return deployedContracts
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<BaseArkParams & CrossChainParams>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig) {
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
  const fleetDefinition = await getFleetConfig()
  const fleetDeployment = await (
    await import('../common/fleet-deployment-files-helpers')
  ).loadFleetDeploymentJson(fleetDefinition)

  // Use config values for these fields
  const bridgeQueueAddress = config.deployedContracts.bridge?.bridgeQueue.address
  const bridgeRouterAddress = config.deployedContracts.bridge?.bridgeRouter.address
  const targetChainId = Number(config.common.chainId)
  const fleetContractAddress = fleetDeployment?.fleetAddress
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address

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
    fleetName: fleetDefinition.fleetName,
    bridgeQueue: bridgeQueueAddress as Address,
    bridgeRouter: bridgeRouterAddress as Address,
    targetChainId,
    fleetContract: fleetContractAddress as Address,
    accessManager: accessManagerAddress as Address,
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
 * @param {BaseArkParams & CrossChainParams} userInput - The user's input for deployment parameters
 * @param {BaseConfig} config - The configuration object for the current network
 * @param {boolean} isAutomated - Whether this is an automated deployment
 * @returns {Promise<boolean>} Whether the user confirmed the deployment
 */
async function confirmDeployment(
  userInput: BaseArkParams & {
    bridgeQueue: Address
    bridgeRouter: Address
    targetChainId: number
    fleetContract: Address
    accessManager: Address
    bridgeOptions: BridgeOptions
  },
  config: BaseConfig,
  isAutomated: boolean,
) {
  if (isAutomated) return true

  console.log(kleur.yellow('\nDeployment Configuration:'))
  console.log(kleur.blue('Token:'), kleur.cyan(userInput.token.symbol))
  console.log(kleur.blue('Deposit Cap:'), kleur.cyan(userInput.depositCap))
  console.log(kleur.blue('Max Rebalance Outflow:'), kleur.cyan(userInput.maxRebalanceOutflow))
  console.log(kleur.blue('Max Rebalance Inflow:'), kleur.cyan(userInput.maxRebalanceInflow))
  console.log(kleur.blue('Bridge Queue:'), kleur.cyan(userInput.bridgeQueue))
  console.log(kleur.blue('Bridge Router:'), kleur.cyan(userInput.bridgeRouter))
  console.log(kleur.blue('Target Chain ID:'), kleur.cyan(userInput.targetChainId))
  console.log(kleur.blue('Fleet Contract:'), kleur.cyan(userInput.fleetContract))
  console.log(kleur.blue('Access Manager:'), kleur.cyan(userInput.accessManager))
  console.log(kleur.blue('Gas Limit:'), kleur.cyan(userInput.bridgeOptions.adapterParams.gasLimit))

  return await continueDeploymentCheck()
}

/**
 * Deploys the CrossChainArk and FleetProxy contracts
 * @param {BaseConfig} config - The configuration object for the current network
 * @param {BaseArkParams & CrossChainParams} userInput - The user's input for deployment parameters
 * @returns {Promise<CrossChainArkContracts>} The deployed contracts
 */
async function deployCrossChainArkContract(
  config: BaseConfig,
  userInput: BaseArkParams & {
    bridgeQueue: Address
    bridgeRouter: Address
    targetChainId: number
    fleetContract: Address
    accessManager: Address
    bridgeOptions: BridgeOptions
  },
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
        fleetContract: userInput.fleetContract,
        accessManager: userInput.accessManager,
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
