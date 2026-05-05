import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createOriginUSDArkModule,
  OriginUSDArkContracts,
} from '../../ignition/modules/arks/originusd-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails, getProtocolConfig } from '../helpers/validation'

/**
 * Main function to deploy an OriginUSDArk.
 */
export async function deployOriginUSDArk(config: BaseConfig, arkParams?: BaseArkParams) {
  console.log(kleur.green().bold('Starting OriginUSDArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedOriginUSDArk = await deployOriginUSDArkContract(config, userInput)
    return { ark: deployedOriginUSDArk.originUSDArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<BaseArkParams> {
  const fleetConfig = await getFleetConfig()

  const responses = await prompts([
    {
      type: 'select',
      name: 'token',
      message: 'Select the token to use for the OriginUSD Ark:',
      choices: [{ title: 'USDC', value: Token.USDC }],
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

  return {
    token: {
      address: config.tokens[responses.token as Token],
      symbol: responses.token as Token,
    },
    depositCap: responses.depositCap,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxDepositPercentageOfTVL: responses.maxDepositPercentageOfTVL,
    fleetName: fleetConfig.fleetName,
    version: 1,
  }
}

async function confirmDeployment(
  userInput: BaseArkParams,
  config: BaseConfig,
  skip: boolean,
): Promise<boolean> {
  console.log(kleur.yellow().bold('\nDeployment Configuration:'))
  console.log(kleur.yellow(`Token: ${userInput.token.symbol}`))
  console.log(kleur.yellow(`Token Address: ${userInput.token.address}`))
  console.log(kleur.yellow(`Fleet Name: ${userInput.fleetName}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployOriginUSDArkContract(
  config: BaseConfig,
  userInput: BaseArkParams,
): Promise<OriginUSDArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `OriginUSD-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}` + '_' + 'gov'

  const originUSDAddress = validateAddress(
    getProtocolConfig(config, 'originUSD').originUSD,
    'OriginUSD',
  )

  const arkDetails = {
    protocol: 'Origin',
    type: 'Vault',
    asset: userInput.token.address,
    marketAsset: userInput.token.address, // OUSD address is fetched in constructor, but logically this Ark manages USDC deposits into OUSD
    pool: originUSDAddress,
    chainId: chainId,
  }

  validateArkDetails(arkDetails, 'Originusd ark details')

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

  return (await hre.ignition.deploy(createOriginUSDArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        originUSD: originUSDAddress,
        arkParams,
      },
    },
    deploymentId,
  })) as OriginUSDArkContracts
}
