import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createHyperBeatCoreArkModule,
  HyperBeatCoreArkContracts,
} from '../../ignition/modules/arks/hyperbeatcore-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface HyperBeatCoreArkUserInput extends BaseArkParams {
  vaultToken: Address
  depositor: Address
  withdrawalQueue: Address
  vaultName: string
}

/**
 * Main function to deploy a HyperBeatCoreArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the HyperBeatCoreArk contract
 * - Logging deployment results
 */
export async function deployHyperBeatCoreArk(
  config: BaseConfig,
  arkParams?: HyperBeatCoreArkUserInput,
) {
  console.log(kleur.green().bold('Starting HyperBeatCoreArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedHyperBeatCoreArk = await deployHyperBeatCoreArkContract(config, userInput)
    return { ark: deployedHyperBeatCoreArk.hyperBeatCoreArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for HyperBeatCoreArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<HyperBeatCoreArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<HyperBeatCoreArkUserInput> {
  // Extract HyperBeatCore vaults from the configuration
  const hyperBeatCoreVaults = []
  for (const token in config.protocolSpecific.hyperbeatcore) {
    for (const vaultName in config.protocolSpecific.hyperbeatcore[token as Token]) {
      const vaultConfig = config.protocolSpecific.hyperbeatcore[token as Token][vaultName]
      hyperBeatCoreVaults.push({
        title: `${token.toUpperCase()} - ${vaultName}`,
        value: {
          token,
          vaultName,
          vaultToken: vaultConfig.vaultToken,
          depositor: vaultConfig.depositor,
          withdrawalQueue: vaultConfig.withdrawalQueue,
        },
      })
    }
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'vaultSelection',
      message: 'Select a HyperBeatCore vault:',
      choices: hyperBeatCoreVaults,
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
    {
      type: 'text',
      name: 'maxDepositPercentageOfTVL',
      initial: HUNDRED_PERCENT,
      message: 'Enter the max deposit percentage of TVL:',
    },
  ])

  // Set the token address based on the selected vault
  const selectedVault = responses.vaultSelection
  const tokenAddress = config.tokens[selectedVault.token as Token]

  const aggregatedData = {
    depositCap: responses.depositCap,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxDepositPercentageOfTVL: responses.maxDepositPercentageOfTVL,
    token: { address: tokenAddress, symbol: selectedVault.token },
    vaultToken: selectedVault.vaultToken,
    depositor: selectedVault.depositor,
    withdrawalQueue: selectedVault.withdrawalQueue,
    vaultName: selectedVault.vaultName,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {HyperBeatCoreArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: HyperBeatCoreArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} - ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Vault Name: ${userInput.vaultName}`))
  console.log(kleur.yellow(`Vault Token: ${userInput.vaultToken}`))
  console.log(kleur.yellow(`Depositor: ${userInput.depositor}`))
  console.log(kleur.yellow(`Withdrawal Queue: ${userInput.withdrawalQueue}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the HyperBeatCoreArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {HyperBeatCoreArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<HyperBeatCoreArkContracts>} The deployed HyperBeatCoreArk contract.
 */
async function deployHyperBeatCoreArkContract(
  config: BaseConfig,
  userInput: HyperBeatCoreArkUserInput,
): Promise<HyperBeatCoreArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `HyperBeatCore-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const depositorAddress = validateAddress(userInput.depositor, 'HyperBeatCore Depositor')

  const withdrawalQueueAddress = validateAddress(
    userInput.withdrawalQueue,
    'HyperBeatCore WithdrawalQueue',
  )

  // Create and validate ark details
  const arkDetails = {
    protocol: 'HyperBeatCore',
    type: 'Vault',
    asset: userInput.token.address,
    pool: userInput.vaultToken,
    depositor: depositorAddress,
    withdrawalQueue: withdrawalQueueAddress,
    chainId: chainId,
    vaultName: userInput.vaultName,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'HyperBeatCore ark details')

  return (await hre.ignition.deploy(createHyperBeatCoreArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        depositor: depositorAddress,
        withdrawalQueue: withdrawalQueueAddress,
        arkParams: {
          name: `HyperBeatCore-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`,
          details: JSON.stringify(arkDetails),
          accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
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
  })) as HyperBeatCoreArkContracts
}
