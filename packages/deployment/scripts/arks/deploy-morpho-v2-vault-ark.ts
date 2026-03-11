import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createMorphoV2VaultArkModule,
  MorphoV2VaultArkContracts,
} from '../../ignition/modules/arks/morpho-v2-vault-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface MorphoV2VaultArkUserInput extends BaseArkParams {
  vaultId: Address
  vaultName: string
}

/**
 * Main function to deploy a MorphoV2VaultArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MorphoV2VaultArk contract
 * - Logging deployment results
 */
export async function deployMorphoV2VaultArk(
  config: BaseConfig,
  arkParams?: MorphoV2VaultArkUserInput,
) {
  console.log(kleur.green().bold('Starting MorphoV2VaultArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedMorphoV2VaultArk = await deployMorphoV2VaultArkContract(config, userInput)
    return { ark: deployedMorphoV2VaultArk.morphoV2VaultArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for MorphoV2VaultArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<MorphoV2VaultArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<MorphoV2VaultArkUserInput> {
  // Extract Morpho V2 vaults from the configuration
  const morphoV2Vaults = []
  const vaultsV2 = config.protocolSpecific.morpho.vaultsV2
  if (!vaultsV2) {
    throw new Error('No Morpho V2 vaults found in the configuration (morpho.vaultsV2).')
  }
  for (const token in vaultsV2) {
    for (const vaultName in vaultsV2[token]) {
      const vaultId = vaultsV2[token][vaultName]
      morphoV2Vaults.push({
        title: `${token.toUpperCase()} - ${vaultName}`,
        value: { token, vaultId, vaultName },
      })
    }
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'vaultSelection',
      message: 'Select a Morpho V2 vault:',
      choices: morphoV2Vaults,
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
    vaultId: selectedVault.vaultId,
    vaultName: selectedVault.vaultName,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {MorphoV2VaultArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: MorphoV2VaultArkUserInput,
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
 * Deploys the MorphoV2VaultArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {MorphoV2VaultArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<MorphoV2VaultArkContracts>} The deployed MorphoV2VaultArk contract.
 */
async function deployMorphoV2VaultArkContract(
  config: BaseConfig,
  userInput: MorphoV2VaultArkUserInput,
): Promise<MorphoV2VaultArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `MorphoV2Vault-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const vaultAddress = validateAddress(userInput.vaultId, 'Morpho V2 vault')

  // Create and validate ark details
  const arkDetails = {
    protocol: 'Morpho_V2',
    type: 'Vault',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: userInput.vaultId,
    chainId: chainId,
    vaultName: userInput.vaultName,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'MorphoV2Vault ark details')

  return (await hre.ignition.deploy(createMorphoV2VaultArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        vault: vaultAddress,
        arkParams: {
          name: `MorphoV2Vault-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`,
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
  })) as MorphoV2VaultArkContracts
}
