import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createFluidFTokenArkModule,
  FluidFTokenArkContracts,
} from '../../ignition/modules/arks/fluid-ftoken-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export async function deployFluidFTokenArk(config: BaseConfig, arkParams?: BaseArkParams) {
  console.log(kleur.green().bold('Starting FluidFTokenArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployed = await deployFluidFTokenArkContract(config, userInput)
    return { ark: deployed.fluidFTokenArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<BaseArkParams> {
  const tokens = []
  if (!config.protocolSpecific.erc4626) {
    throw new Error('No ERC4626 vaults found in the configuration.')
  }
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    const fluidFTokenConfig = config.protocolSpecific.fluid.fToken[tokenSymbol as Token]
    if (fluidFTokenConfig && fluidFTokenConfig.fToken && fluidFTokenConfig.merkleDistributor) {
      tokens.push({
        title: tokenSymbol.toUpperCase(),
        value: { address: tokenAddress, symbol: tokenSymbol.toUpperCase() },
      })
    }
  }

  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'vaultSelection',
      message: 'Select an ERC4626 vault (fToken wrapper):',
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

  const selectedVault = responses.vaultSelection
  const tokenAddress = config.tokens[selectedVault.token as Token]

  return {
    depositCap: responses.depositCap,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxDepositPercentageOfTVL: responses.maxDepositPercentageOfTVL,
    token: { address: tokenAddress, symbol: selectedVault.token },
    fleetName: fleetDefinition.fleetName,
  }
}

async function confirmDeployment(userInput: BaseArkParams, _config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployFluidFTokenArkContract(
  config: BaseConfig,
  userInput: BaseArkParams,
): Promise<FluidFTokenArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `FluidFToken-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const fToken = validateAddress(
    config.protocolSpecific.fluid.fToken[userInput.token.symbol].fToken,
    'Fluid fToken',
  )

  const protocol = 'Fluid'

  // Create and validate ark details

  const arkDetails = {
    protocol: protocol,
    type: 'FluidFToken',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: fToken,
    chainId: chainId,
    vaultName: userInput.token.symbol,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'FluidFtoken ark details')

  return (await hre.ignition.deploy(createFluidFTokenArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        vault: fToken,
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
  })) as FluidFTokenArkContracts
}
