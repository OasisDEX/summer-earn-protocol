import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createSiUSDArkModule, SiUSDArkContracts } from '../../ignition/modules/arks/siusd-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateArkDetails } from '../helpers/validation'

export interface SiUSDArkUserInput extends BaseArkParams {
  gateway: Address
  siUSD: Address
}

export async function deploySiUSDArk(config: BaseConfig, arkParams?: SiUSDArkUserInput) {
  console.log(kleur.green().bold('Starting SiUSDArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedSiUSDArk = await deploySiUSDArkContract(config, userInput)
    return { ark: deployedSiUSDArk.siUSDArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
    return undefined
  }
}

async function getUserInput(config: BaseConfig): Promise<SiUSDArkUserInput> {
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'text',
      name: 'gateway',
      message: 'Enter the InfiniFi Gateway address:',
      validate: (value) => (value ? true : 'Gateway address is required'),
    },
    {
      type: 'text',
      name: 'siUSD',
      message: 'Enter the siUSD vault address:',
      validate: (value) => (value ? true : 'siUSD vault address is required'),
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

  // SiUSDArk only supports USDC
  const tokenAddress = config.tokens[Token.USDC]

  const aggregatedData = {
    depositCap: responses.depositCap,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxDepositPercentageOfTVL: responses.maxDepositPercentageOfTVL,
    token: { address: tokenAddress as Address, symbol: Token.USDC },
    gateway: responses.gateway as Address,
    siUSD: responses.siUSD as Address,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

async function confirmDeployment(userInput: SiUSDArkUserInput, config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Gateway Address        : ${userInput.gateway}`))
  console.log(kleur.yellow(`siUSD Vault Address    : ${userInput.siUSD}`))
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deploySiUSDArkContract(
  config: BaseConfig,
  userInput: SiUSDArkUserInput,
): Promise<SiUSDArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `SiUSDArk-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`
  console.log(moduleName)

  // Create and validate ark details

  const arkDetails = {
    protocol: 'InfiniFi',
    type: 'SiUSDArk',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    gateway: userInput.gateway,
    pool: userInput.siUSD,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'Siusd ark details')

  return (await hre.ignition.deploy(createSiUSDArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        gateway: userInput.gateway,
        siUSD: userInput.siUSD,
        arkParams: {
          name: arkName,
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
  })) as SiUSDArkContracts
}
