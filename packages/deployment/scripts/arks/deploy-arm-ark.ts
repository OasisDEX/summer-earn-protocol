import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { ArmArkContracts, createArmArkModule } from '../../ignition/modules/arks/arm-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

/**
 * Main function to deploy an ArmArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the ArmArk contract
 * - Logging deployment results
 */
export async function deployArmArk(
  config: BaseConfig,
  arkParams?: BaseArkParams & { vaultName?: string },
) {
  console.log(kleur.green().bold('Starting ArmArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedArmArk = await deployArmArkContract(config, userInput)
    return { ark: deployedArmArk.armArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Gets user input for ArmArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<BaseArkParams & { vaultName: string }>} The user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<BaseArkParams & { vaultName: string }> {
  const fleetConfig = await getFleetConfig()

  console.log(kleur.yellow('ArmArk only supports WETH as the asset.'))

  const availableArms = Object.keys(config.protocolSpecific.originETH.arms[Token.WETH] || {})
  if (availableArms.length === 0) {
    throw new Error('No ARM configurations found for WETH in the config')
  }

  const armChoice = await prompts({
    type: 'select',
    name: 'value',
    message: 'Select the ARM strategy to use:',
    choices: availableArms.map((arm) => ({ title: arm, value: arm })),
  })

  if (!armChoice.value) {
    throw new Error('ARM strategy selection is required')
  }

  return {
    token: {
      address: config.tokens[Token.WETH],
      symbol: Token.WETH,
    },
    depositCap: '0',
    maxRebalanceOutflow: MAX_UINT256_STRING,
    maxRebalanceInflow: MAX_UINT256_STRING,
    maxDepositPercentageOfTVL: HUNDRED_PERCENT,
    fleetName: fleetConfig.fleetName,
    vaultName: armChoice.value,
  }
}

/**
 * Confirms the deployment with the user.
 * @param {BaseArkParams & { vaultName?: string }} userInput - The user's input for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {boolean} isNonInteractive - Whether the deployment is non-interactive.
 * @returns {Promise<boolean>} Whether the user confirmed the deployment.
 */
async function confirmDeployment(
  userInput: BaseArkParams & { vaultName?: string },
  config: BaseConfig,
  isNonInteractive: boolean,
): Promise<boolean> {
  if (isNonInteractive) {
    return true
  }

  console.log(kleur.yellow().bold('\nDeployment Configuration:'))
  console.log(kleur.yellow(`Token: ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Token Address: ${userInput.token.address}`))
  console.log(kleur.yellow(`ARM Strategy: ${userInput.vaultName}`))
  console.log(kleur.yellow(`Fleet Name: ${userInput.fleetName}`))

  return await continueDeploymentCheck()
}

/**
 * Deploys the ArmArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {BaseArkParams & { vaultName?: string }} userInput - The user's input for deployment parameters.
 * @returns {Promise<ArmArkContracts>} The deployed ArmArk contract.
 */
async function deployArmArkContract(
  config: BaseConfig,
  userInput: BaseArkParams & { vaultName?: string },
): Promise<ArmArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const vaultName = userInput.vaultName || 'default'
  const arkName = `Origin_ARM-${userInput.token.symbol}-${vaultName}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  // Look up ARM address from config based on token and vaultName
  const armConfigs = config.protocolSpecific.originETH.arms[userInput.token.symbol as Token]
  if (!armConfigs || !armConfigs[vaultName]) {
    throw new Error(
      `No ARM configuration found for ${userInput.token.symbol} with vault name ${vaultName}`,
    )
  }
  const armAddress = validateAddress(armConfigs[vaultName], `OriginETH ARM ${vaultName}`)

  // Create and validate ark details

  const arkDetails = {
    protocol: 'Origin',
    type: 'ARM',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: armAddress,
    armStrategy: vaultName,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'Arm ark details')

  const arkParams = {
    name: arkName,
    details: JSON.stringify(arkDetails),
    accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
    configurationManager: config.deployedContracts.core.configurationManager.address as Address,
    asset: userInput.token.address,
    depositCap: userInput.depositCap,
    maxRebalanceOutflow: userInput.maxRebalanceOutflow,
    maxRebalanceInflow: userInput.maxRebalanceInflow,
    requiresKeeperData: false,
    maxDepositPercentageOfTVL: userInput.maxDepositPercentageOfTVL,
  }

  console.log('arkParams', arkParams)

  // ArmArk is currently only supported on mainnet
  if (chainId !== 1) {
    throw new Error('ArmArk is currently only supported on mainnet')
  }

  return (await hre.ignition.deploy(createArmArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        arm: armAddress,
        arkParams,
      },
    },
    deploymentId,
  })) as ArmArkContracts
}
