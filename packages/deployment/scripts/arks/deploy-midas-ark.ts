import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createMidasArkModule, MidasArkContracts } from '../../ignition/modules/arks/midas-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface MidasArkUserInput extends BaseArkParams {
  mToken: Address
  issuanceVault: Address
  redemptionVault: Address
  vaultName: string
}

/**
 * Main function to deploy a MidasArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MidasArk contract
 * - Logging deployment results
 */
export async function deployMidasArk(config: BaseConfig, arkParams?: MidasArkUserInput) {
  console.log(kleur.green().bold('Starting MidasArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedMidasArk = await deployMidasArkContract(config, userInput)
    return { ark: deployedMidasArk.midasArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for MidasArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<MidasArkUserInput>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<MidasArkUserInput> {
  // Extract Midas vaults from the configuration
  const midasVaults = []
  for (const token in config.protocolSpecific.midas) {
    for (const vaultName in config.protocolSpecific.midas[token as Token]) {
      const vaultConfig = config.protocolSpecific.midas[token as Token][vaultName]
      midasVaults.push({
        title: `${token.toUpperCase()} - ${vaultName}`,
        value: {
          token,
          vaultName,
          mToken: vaultConfig.mToken,
          issuanceVault: vaultConfig.issuance,
          redemptionVault: vaultConfig.redemption,
        },
      })
    }
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'vaultSelection',
      message: 'Select a Midas vault:',
      choices: midasVaults,
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
    mToken: selectedVault.mToken,
    issuanceVault: selectedVault.issuanceVault,
    redemptionVault: selectedVault.redemptionVault,
    vaultName: selectedVault.vaultName,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {MidasArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: MidasArkUserInput, config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} - ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Vault Name: ${userInput.vaultName}`))
  console.log(kleur.yellow(`mToken: ${userInput.mToken}`))
  console.log(kleur.yellow(`Issuance Vault: ${userInput.issuanceVault}`))
  console.log(kleur.yellow(`Redemption Vault: ${userInput.redemptionVault}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the MidasArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {MidasArkUserInput} userInput - The user's input for deployment parameters.
 * @returns {Promise<MidasArkContracts>} The deployed MidasArk contract.
 */
async function deployMidasArkContract(
  config: BaseConfig,
  userInput: MidasArkUserInput,
): Promise<MidasArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Midas-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const mTokenAddress = validateAddress(userInput.mToken, 'Midas mToken')

  const issuanceVaultAddress = validateAddress(userInput.issuanceVault, 'Midas Issuance Vault')

  const redemptionVaultAddress = validateAddress(
    userInput.redemptionVault,
    'Midas Redemption Vault',
  )

  // Create and validate ark details
  const arkDetails = {
    protocol: 'Midas',
    type: 'Vault',
    asset: userInput.token.address,
    pool: mTokenAddress,
    issuanceVault: issuanceVaultAddress,
    redemptionVault: redemptionVaultAddress,
    chainId: chainId,
    vaultName: userInput.vaultName,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'Midas ark details')

  return (await hre.ignition.deploy(createMidasArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        issuanceVault: issuanceVaultAddress,
        redemptionVault: redemptionVaultAddress,
        arkParams: {
          name: `Midas-${userInput.token.symbol}-${userInput.vaultName}-${chainId}`,
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
  })) as MidasArkContracts
}
