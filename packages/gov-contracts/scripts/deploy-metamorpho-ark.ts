import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { BaseConfig, Tokens, TokenType } from '../ignition/config/config-types'
import MetaMorphoArkModule, {
  MetaMorphoArkContracts,
} from '../ignition/modules/arks/metamorpho-ark'
import { MAX_UINT256_STRING } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { handleDeploymentId } from './helpers/deployment-id-handler'
import { getChainId } from './helpers/get-chainid'
import { ModuleLogger } from './helpers/module-logger'
import { continueDeploymentCheck } from './helpers/prompt-helpers'

/**
 * Main function to deploy a MetaMorphoArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the MetaMorphoArk contract
 * - Logging deployment results
 */
export async function deployMetaMorphoArk() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting MetaMorphoArk deployment process...'))

  const userInput = await getUserInput(config)

  if (await confirmDeployment(userInput)) {
    console.log(kleur.green().bold('Proceeding with deployment...'))

    const deployedMetaMorphoArk = await deployMetaMorphoArkContract(config, userInput)

    console.log(kleur.green().bold('Deployment completed successfully!'))

    // Logging
    ModuleLogger.logMetaMorphoArk(deployedMetaMorphoArk)
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for MetaMorphoArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig) {
  // Extract Morpho vaults from the configuration
  const morphoVaults = []
  for (const token in config.morpho.vaults) {
    for (const vaultName in config.morpho.vaults[token as Tokens]) {
      const vaultId = config.morpho.vaults[token as TokenType][vaultName]
      morphoVaults.push({
        title: `${token.toUpperCase()} - ${vaultName}`,
        value: { token, vaultId },
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
  const tokenAddress = config.tokens[selectedVault.token as TokenType]

  const aggregatedData = {
    ...responses,
    token: tokenAddress,
    vaultId: selectedVault.vaultId,
  }

  return aggregatedData
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(userInput: any) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token}`))
  console.log(kleur.yellow(`Vault ID: ${userInput.vaultId}`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return await continueDeploymentCheck()
}

/**
 * Deploys the MetaMorphoArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {any} userInput - The user's input for deployment parameters.
 * @returns {Promise<MetaMorphoArkContracts>} The deployed MetaMorphoArk contract.
 */
async function deployMetaMorphoArkContract(
  config: BaseConfig,
  userInput: any,
): Promise<MetaMorphoArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)

  return (await hre.ignition.deploy(MetaMorphoArkModule, {
    parameters: {
      MetaMorphoArkModule: {
        strategyVault: userInput.vaultId,
        arkParams: {
          name: 'MetaMorphoArk',
          accessManager: config.core.protocolAccessManager,
          configurationManager: config.core.configurationManager,
          token: userInput.token,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
        },
      },
    },
    deploymentId,
  })) as MetaMorphoArkContracts
}

// Execute the deployMetaMorphoArk function and handle any errors
deployMetaMorphoArk().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
