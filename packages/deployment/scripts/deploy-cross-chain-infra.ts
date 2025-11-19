import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, bytesToHex, keccak256, toBytes } from 'viem'

import { BaseConfig, Token } from '../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from './common/constants'
import { getConfigByNetwork } from './helpers/config-handler'
import { getChainId } from './helpers/get-chainid'
import { continueDeploymentCheck, promptForConfigType } from './helpers/prompt-helpers'
import { warnIfTenderlyVirtualTestnet } from './helpers/tenderly-helpers'
import { updateIndexJson } from './helpers/update-json'

enum DeploymentMode {
  REGISTRY_ONLY = 'registry_only',
  MANAGER_ONLY = 'manager_only',
  REGISTRY_AND_MANAGER = 'registry_and_manager',
  ARK_LITE_ONLY = 'ark_lite_only',
  ALL = 'all',
}

export async function deployCrossChainInfra() {
  const networkName = hre.network.name
  console.log(kleur.blue('Network:'), kleur.cyan(networkName))

  // Check if using Tenderly virtual testnet
  const isTenderly = warnIfTenderlyVirtualTestnet(
    'Deployments on Tenderly virtual testnets are temporary and will be lost when the session ends.',
  )

  if (isTenderly) {
    const response = await prompts({
      type: 'confirm',
      name: 'continue',
      message: 'Do you want to continue with deployment on this Tenderly virtual testnet?',
      initial: false,
    })

    if (!response.continue) {
      console.log(kleur.red('Deployment cancelled.'))
      return
    }
  }

  // Ask about using bummer config
  const useBummerConfig = await promptForConfigType()

  // Load the configuration for the current network
  const config = getConfigByNetwork(
    networkName,
    { common: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  // Choose what to deploy on this chain
  const modeChoices = [
    {
      title: 'Deploy CallValidationRegistry only (for Ark/fleet chain)',
      value: DeploymentMode.REGISTRY_ONLY,
    },
    {
      title: 'Deploy CrossChainManager only (using existing registry)',
      value: DeploymentMode.MANAGER_ONLY,
    },
    {
      title: 'Deploy both CallValidationRegistry and CrossChainManager',
      value: DeploymentMode.REGISTRY_AND_MANAGER,
    },
    {
      title: 'Deploy CrossChainArkLite only (using existing registry)',
      value: DeploymentMode.ARK_LITE_ONLY,
    },
    {
      title: 'Deploy all (Registry, Manager, and ArkLite)',
      value: DeploymentMode.ALL,
    },
  ]

  const modeResponse = await prompts({
    type: 'select',
    name: 'mode',
    message: 'What would you like to deploy on this chain?',
    choices: modeChoices,
  })

  const deploymentMode = modeResponse.mode as DeploymentMode

  // Display summary and get confirmation
  if (!(await confirmDeployment(networkName, deploymentMode))) {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return null
  }

  const { deployer } = await (hre as any).getNamedAccounts()
  const { deploy } = (hre as any).deployments

  let updatedCore = { ...config.deployedContracts.core }
  const accessManagerAddress = config.deployedContracts.gov.protocolAccessManager.address as Address

  // 1) Deploy registry if requested
  if (
    deploymentMode === DeploymentMode.REGISTRY_ONLY ||
    deploymentMode === DeploymentMode.REGISTRY_AND_MANAGER ||
    deploymentMode === DeploymentMode.ALL
  ) {
    console.log(kleur.cyan().bold('Deploying CallValidationRegistry...'))
    const keccakSalt = keccak256(toBytes('call-validation-registry'))
    const registryDeployment = await deploy('CallValidationRegistry', {
      from: deployer,
      args: [accessManagerAddress],
      log: true,
      deterministicDeployment: keccakSalt,
    })

    console.log(kleur.green().bold('CallValidationRegistry deployed successfully!'))

    updatedCore = {
      ...updatedCore,
      callValidationRegistry: {
        address: registryDeployment.address as Address,
      },
    }
  }

  // 2) Deploy manager if requested
  if (
    deploymentMode === DeploymentMode.MANAGER_ONLY ||
    deploymentMode === DeploymentMode.REGISTRY_AND_MANAGER ||
    deploymentMode === DeploymentMode.ALL
  ) {
    console.log(kleur.cyan().bold('Deploying CrossChainManager...'))

    // Resolve validation registry address for manager deployment
    let validationRegistryAddress: Address | undefined = updatedCore.callValidationRegistry
      ?.address as Address | undefined

    if (!validationRegistryAddress) {
      // Fallback to existing config, if present
      validationRegistryAddress = config.deployedContracts.core.callValidationRegistry?.address as
        | Address
        | undefined
    }

    if (!validationRegistryAddress) {
      // Ask user for registry address
      const { registry } = await prompts({
        type: 'text',
        name: 'registry',
        message:
          'Enter the address of an existing CallValidationRegistry to use with CrossChainManager:',
        validate: (value) => (value.startsWith('0x') ? true : 'Invalid address format'),
      })

      validationRegistryAddress = registry as Address
    }

    const keccakSalt = keccak256(toBytes('cross-chain-manager'))
    const managerDeployment = await deploy('CrossChainManager', {
      from: deployer,
      args: [
        config.deployedContracts.core.configurationManager.address,
        validationRegistryAddress,
        accessManagerAddress,
      ],
      log: true,
      deterministicDeployment: keccakSalt,
    })

    console.log(kleur.green().bold('CrossChainManager deployed successfully!'))

    updatedCore = {
      ...updatedCore,
      crossChainManager: {
        address: managerDeployment.address as Address,
      },
    }
  }

  // 3) Deploy CrossChainArkLite if requested
  if (deploymentMode === DeploymentMode.ARK_LITE_ONLY || deploymentMode === DeploymentMode.ALL) {
    console.log(kleur.cyan().bold('Deploying CrossChainArkLite...'))

    // Resolve validation registry address for ArkLite deployment
    let validationRegistryAddress: Address | undefined = updatedCore.callValidationRegistry
      ?.address as Address | undefined

    if (!validationRegistryAddress) {
      // Fallback to existing config, if present
      validationRegistryAddress = config.deployedContracts.core.callValidationRegistry?.address as
        | Address
        | undefined
    }

    if (!validationRegistryAddress) {
      // Ask user for registry address
      const { registry } = await prompts({
        type: 'text',
        name: 'registry',
        message:
          'Enter the address of an existing CallValidationRegistry to use with CrossChainArkLite:',
        validate: (value) => (value.startsWith('0x') ? true : 'Invalid address format'),
      })

      validationRegistryAddress = registry as Address
    }

    // Get user input for ArkLite deployment
    const arkLiteInput = await getArkLiteUserInput(config)

    // Build ArkParams
    const chainId = getChainId()
    const arkName = `CrossChainArkLite-${arkLiteInput.token.symbol}-${chainId}`
    const arkDetails = {
      protocol: 'CrossChain',
      type: 'CrossChainLite',
      asset: arkLiteInput.token.address,
      chainId: chainId,
    }

    const arkParams = {
      name: arkName,
      details: JSON.stringify(arkDetails),
      accessManager: accessManagerAddress,
      configurationManager: config.deployedContracts.core.configurationManager.address as Address,
      asset: arkLiteInput.token.address,
      depositCap: arkLiteInput.depositCap,
      maxRebalanceOutflow: arkLiteInput.maxRebalanceOutflow,
      maxRebalanceInflow: arkLiteInput.maxRebalanceInflow,
      requiresKeeperData: false,
      maxDepositPercentageOfTVL: arkLiteInput.maxDepositPercentageOfTVL,
    }

    const keccakSalt = keccak256(toBytes('cross-chain-ark-lite'))
    const arkLiteDeployment = await deploy('CrossChainArkLite', {
      from: deployer,
      args: [arkParams, validationRegistryAddress],
      log: true,
      deterministicDeployment: keccakSalt,
    })

    console.log(kleur.green().bold('CrossChainArkLite deployed successfully!'))
    console.log(kleur.blue('CrossChainArkLite address:'), kleur.cyan(arkLiteDeployment.address))
    console.log(
      kleur.yellow(
        'Note: CrossChainArkLite addresses are typically managed through fleet deployments.',
      ),
    )
  }

  // Persist addresses into core config
  await updateIndexJson('core', networkName, updatedCore, useBummerConfig)

  return updatedCore
}

/**
 * Prompts the user for CrossChainArkLite deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<object>} An object containing the user's input for deployment parameters.
 */
async function getArkLiteUserInput(config: BaseConfig) {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    tokens.push({
      title: tokenSymbol.toUpperCase(),
      value: { address: tokenAddress, symbol: tokenSymbol },
    })
  }

  const responses = await prompts([
    {
      type: 'select',
      name: 'token',
      message: 'Select token for CrossChainArkLite:',
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
    {
      type: 'text',
      name: 'maxDepositPercentageOfTVL',
      initial: HUNDRED_PERCENT,
      message: 'Enter the max deposit percentage of TVL:',
    },
  ])

  return responses
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {string} network - The network being deployed to.
 * @param {DeploymentMode} mode - What is being deployed.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(network: string, mode: DeploymentMode): Promise<boolean> {
  console.log(kleur.yellow(`Cross-chain infra (${mode}) will be deployed on: ${network}`))
  return await continueDeploymentCheck()
}

deployCrossChainInfra().catch((error) => {
  console.error(kleur.red().bold('An error occurred during cross-chain infra deployment:'), error)
  process.exit(1)
})
