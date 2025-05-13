import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createOriginETHArkModule,
  OriginETHArkContracts,
} from '../../ignition/modules/arks/origineth-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress } from '../helpers/validation'

/**
 * Main function to deploy an OriginETHArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the OriginETHArk contract
 * - Logging deployment results
 */
export async function deployOriginETHArk(config: BaseConfig, arkParams?: BaseArkParams) {
  console.log(kleur.green().bold('Starting OriginETHArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedOriginETHArk = await deployOriginETHArkContract(config, userInput)
    return { ark: deployedOriginETHArk.originETHArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Gets user input for OriginETHArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<BaseArkParams>} The user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<BaseArkParams> {
  const fleetConfig = await getFleetConfig()

  const token = await prompts({
    type: 'select',
    name: 'value',
    message: 'Select the token to use for the OriginETH Ark:',
    choices: [{ title: 'WETH', value: Token.WETH }],
  })

  if (!token.value) {
    throw new Error('Token selection is required')
  }

  const selectedToken = token.value as Token

  return {
    token: {
      address: config.tokens[selectedToken],
      symbol: selectedToken,
    },
    depositCap: '0',
    maxRebalanceOutflow: MAX_UINT256_STRING,
    maxRebalanceInflow: MAX_UINT256_STRING,
    fleetName: fleetConfig.fleetName,
  }
}

/**
 * Confirms the deployment with the user.
 * @param {BaseArkParams} userInput - The user's input for deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {boolean} isNonInteractive - Whether the deployment is non-interactive.
 * @returns {Promise<boolean>} Whether the user confirmed the deployment.
 */
async function confirmDeployment(
  userInput: BaseArkParams,
  config: BaseConfig,
  isNonInteractive: boolean,
): Promise<boolean> {
  if (isNonInteractive) {
    return true
  }

  console.log(kleur.yellow().bold('\nDeployment Configuration:'))
  console.log(kleur.yellow(`Token: ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Token Address: ${userInput.token.address}`))
  console.log(kleur.yellow(`Fleet Name: ${userInput.fleetName}`))

  return await continueDeploymentCheck()
}

/**
 * Deploys the OriginETHArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {BaseArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<OriginETHArkContracts>} The deployed OriginETHArk contract.
 */
async function deployOriginETHArkContract(
  config: BaseConfig,
  userInput: BaseArkParams,
): Promise<OriginETHArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Origin-${userInput.token.symbol}-${chainId}`
  const moduleName = userInput.fleetName + '_' + arkName.replace(/-/g, '_') + '_' + 'staging'

  const originETHAddress = validateAddress(config.protocolSpecific.originETH.originETH, 'OriginETH')
  const armAddress = validateAddress(config.protocolSpecific.originETH.arm, 'OriginETH ARM')

  console.log('originETHAddress', originETHAddress)
  console.log('armAddress', armAddress)
  const arkParams = {
    name: arkName,
    details: JSON.stringify({
      protocol: 'Origin',
      type: 'Lending',
      asset: userInput.token.address,
      marketAsset: userInput.token.address,
      pool: originETHAddress,
      chainId: chainId,
    }),
    accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
    configurationManager: config.deployedContracts.core.configurationManager.address as Address,
    asset: userInput.token.address,
    depositCap: userInput.depositCap,
    maxRebalanceOutflow: userInput.maxRebalanceOutflow,
    maxRebalanceInflow: userInput.maxRebalanceInflow,
    requiresKeeperData: false,
    maxDepositPercentageOfTVL: HUNDRED_PERCENT,
  }
  console.log('arkParams', arkParams)
  return (await hre.ignition.deploy(createOriginETHArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        originETH: originETHAddress,
        arm: armAddress,
        arkParams,
      },
    },
    deploymentId,
  })) as OriginETHArkContracts
}
