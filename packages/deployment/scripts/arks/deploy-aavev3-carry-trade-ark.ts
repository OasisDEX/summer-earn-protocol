import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  AaveV3CarryTradeArkContracts,
  createAaveV3CarryTradeArkModule,
} from '../../ignition/modules/arks/aavev3-carry-trade-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateErc4626Address } from '../helpers/validation'

interface AaveV3CarryTradeArkParams extends BaseArkParams {
  vaultId: string
  vaultName: string
  maxLtv: string
  slippage: string
}

/**
 * Main function to deploy an AaveV3CarryTradeArk.
 * This function orchestrates the entire deployment process, including:
 * - Getting configuration for the current network
 * - Collecting user input for deployment parameters
 * - Confirming deployment with the user
 * - Deploying the AaveV3CarryTradeArk contract
 * - Logging deployment results
 */
export async function deployAaveV3CarryTradeArk(
  config: BaseConfig,
  arkParams?: AaveV3CarryTradeArkParams,
) {
  console.log(kleur.green().bold('Starting AaveV3CarryTradeArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedAaveV3CarryTradeArk = await deployAaveV3CarryTradeArkContract(config, userInput)
    return { ark: deployedAaveV3CarryTradeArk.aaveV3CarryTradeArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

/**
 * Prompts the user for AaveV3CarryTradeArk deployment parameters.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @returns {Promise<any>} An object containing the user's input for deployment parameters.
 */
async function getUserInput(config: BaseConfig): Promise<AaveV3CarryTradeArkParams> {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    tokens.push({
      title: tokenSymbol,
      value: { address: tokenAddress, symbol: tokenSymbol },
    })
  }
  const fleetDefinition = await getFleetConfig()

  // Get token selection first
  const tokenResponse = await prompts([
    {
      type: 'select',
      name: 'token',
      message: 'Select token the borrowed asset :',
      choices: tokens,
    },
  ])

  // Get available yield vaults for the selected token
  const yieldVaults = []
  for (const vaultName in config.protocolSpecific.erc4626[tokenResponse.token.symbol as Token]) {
    const vaultAddress =
      config.protocolSpecific.erc4626[tokenResponse.token.symbol as Token][vaultName]
    yieldVaults.push({
      title: vaultName,
      value: { address: vaultAddress, name: vaultName },
    })
  }

  const responses = await prompts([
    {
      type: 'select',
      name: 'yieldVault',
      message: 'Select yield vault:',
      choices: yieldVaults,
    },
    {
      type: 'text',
      name: 'maxLtv',
      initial: '5000',
      message: 'Enter the max LTV:',
    },
    {
      type: 'text',
      name: 'slippage',
      initial: '100',
      message: 'Enter the slippage:',
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
    vaultId: responses.yieldVault.address,
    vaultName: responses.yieldVault.name,
    token: tokenResponse.token,
    fleetName: fleetDefinition.fleetName,
  }
}

/**
 * Displays a summary of the deployment parameters and asks for user confirmation.
 * @param {AaveV3CarryTradeArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<boolean>} True if the user confirms, false otherwise.
 */
async function confirmDeployment(
  userInput: AaveV3CarryTradeArkParams,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Token: ${userInput.token.address} (${userInput.token.symbol})`))
  console.log(kleur.yellow(`Yield Vault: ${userInput.vaultId} (${userInput.vaultName})`))
  console.log(kleur.yellow(`Deposit Cap: ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow: ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow: ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

/**
 * Deploys the AaveV3CarryTradeArk contract using Hardhat Ignition.
 * @param {BaseConfig} config - The configuration object for the current network.
 * @param {AaveV3CarryTradeArkParams} userInput - The user's input for deployment parameters.
 * @returns {Promise<AaveV3CarryTradeArkContracts>} The deployed AaveV3CarryTradeArk contract.
 */
async function deployAaveV3CarryTradeArkContract(
  config: BaseConfig,
  userInput: AaveV3CarryTradeArkParams,
): Promise<AaveV3CarryTradeArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `AaveV3CarryTrade-${userInput.token.symbol}-${chainId}`
  const moduleName = userInput.fleetName + '_' + arkName.replace(/-/g, '_')

  const lendingPool = validateAddress(config.protocolSpecific.aaveV3.pool, 'lending pool')
  const yieldVault = validateErc4626Address(userInput.vaultId, 'yield vault')
  const rewardsController = validateAddress(
    config.protocolSpecific.aaveV3.rewards,
    'rewards controller',
  )
  const poolAddressesProvider = validateAddress(
    config.protocolSpecific.aaveV3.poolAddressesProvider,
    'pool addresses provider',
  )
  const targetVault = await hre.viem.getContractAt('ERC4626' as string, yieldVault)
  const borrowedAsset = await targetVault.read.asset()
  const borrowedAssetAddress = validateErc4626Address(borrowedAsset, 'borrowed asset')

  return (await hre.ignition.deploy(createAaveV3CarryTradeArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        lendingPool: lendingPool,
        borrowedAsset: borrowedAssetAddress,
        yieldVault: yieldVault,
        maxLtv: userInput.maxLtv,
        slippage: userInput.slippage,
        rewardsController: rewardsController,
        poolAddressesProvider: poolAddressesProvider,
        arkParams: {
          name: `AaveV3CarryTrade-${userInput.token.symbol}-${chainId}`,
          details: JSON.stringify({
            protocol: 'AaveV3CarryTrade',
            type: 'CarryTrade',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            lendingPool: lendingPool,
            borrowedAsset: borrowedAsset,
            yieldVault: yieldVault,
            yieldVaultName: userInput.vaultName,
            chainId: chainId,
          }),
          accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
          asset: userInput.token.address,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: true,
          maxDepositPercentageOfTVL: HUNDRED_PERCENT,
        },
      },
    },
    deploymentId,
  })) as AaveV3CarryTradeArkContracts
}
