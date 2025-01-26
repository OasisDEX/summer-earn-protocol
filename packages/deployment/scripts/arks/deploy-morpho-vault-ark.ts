import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createMorphoVaultArkModule,
  MorphoVaultArkContracts,
} from '../../ignition/modules/arks/morpho-vault-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress } from '../helpers/validation'

export interface MorphoVaultArkUserInput {
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  token: { address: Address; symbol: Token }
  vaultId: Address
  vaultName: string
}

/**
 * Main function to deploy a MorphoVaultArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MorphoVaultArk contract
 * - Logging deployment results
 */
export async function deployMorphoVaultArk(
  config: BaseConfig,
  arkParams?: MorphoVaultArkUserInput,
) {
  console.log(kleur.green().bold('Starting MorphoVaultArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedMorphoVaultArk = await deployMorphoVaultArkContract(config, userInput)
    return { ark: deployedMorphoVaultArk.morphoVaultArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for MorphoVaultArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<MorphoVaultArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<MorphoVaultArkUserInput> {
  // Extract Morpho vaults from the configuration
  const morphoVaults = []
  for (const token in config.protocolSpecific.morpho.vaults) {
    for (const vaultName in config.protocolSpecific.morpho.vaults[token as Token]) {
      const vaultId = config.protocolSpecific.morpho.vaults[token as Token][vaultName]
      morphoVaults.push({
        title: `${token.toUpperCase()} - ${vaultName}`,
        value: { token, vaultId, vaultName },
      })
    }
  }

  const responses = await prompts([
    {
      type: 'select',
      name: 'vaultSelection',
      message: 'Select a Morpho vault:',
      choices: morphoVaults,
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

  // Set the token address based on the selected vault
  const selectedVault = responses.vaultSelection
  const tokenAddress = config.tokens[selectedVault.token as Token]

  const aggregatedData = {
    depositCap: responses.depositCap,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    token: { address: tokenAddress, symbol: selectedVault.token },
    vaultId: selectedVault.vaultId,
    vaultName: selectedVault.vaultName,
  }

  return aggregatedData
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {MorphoVaultArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: MorphoVaultArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} - ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Vault ID: ${userInput.vaultId}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the MorphoVaultArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {MorphoVaultArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<MorphoVaultArkContracts>} The deployed MorphoVaultArk contract.
 */
async function deployMorphoVaultArkContract(
  config: BaseConfig,
  userInput: MorphoVaultArkUserInput,
): Promise<MorphoVaultArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `MorphoVault-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`
  const moduleName = arkName.replace(/-/g, '_')

  const urdFactoryAddress = validateAddress(
    config.protocolSpecific.morpho.urdFactory,
    'Morpho URD Factory',
  )

  return (await hre.ignition.deploy(createMorphoVaultArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        strategyVault: userInput.vaultId,
        urdFactory: urdFactoryAddress,
        arkParams: {
          name: `MorphoVault-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`,
          details: JSON.stringify({
            protocol: 'Morpho',
            type: 'Vault',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: userInput.vaultId,
            chainId: chainId,
            vaultName: userInput.vaultName,
          }),
          accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
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
  })) as MorphoVaultArkContracts
}
