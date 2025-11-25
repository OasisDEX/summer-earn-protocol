import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createFluidLiteArkModule } from '../../ignition/modules/arks/fluid-lite-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface FluidLiteArkUserInput extends BaseArkParams {
  token: { address: Address; symbol: Token }
}

export interface FluidLiteArkContracts {
  fluidLiteArk: { address: string }
}

export async function deployFluidLiteArk(config: BaseConfig, arkParams?: FluidLiteArkUserInput) {
  console.log(kleur.green().bold('Starting FluidLiteArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedFluidLiteArk = await deployFluidLiteArkContract(config, userInput)
    return { ark: deployedFluidLiteArk.fluidLiteArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<FluidLiteArkUserInput> {
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    // Only add tokens that have a corresponding Fluid Lite configuration
    const fluidLiteConfig = config.protocolSpecific.fluid.lite[tokenSymbol as Token]
    if (
      fluidLiteConfig &&
      fluidLiteConfig.wrapper &&
      fluidLiteConfig.vault &&
      fluidLiteConfig.withdrawalQueue
    ) {
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
      name: 'token',
      message: 'Select token:',
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

  return {
    ...responses,
    fleetName: fleetDefinition.fleetName,
  }
}

async function confirmDeployment(
  userInput: FluidLiteArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  if (skip) return true

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: 'Do you want to proceed with the deployment?',
    initial: true,
  })

  return confirmed
}

async function deployFluidLiteArkContract(
  config: BaseConfig,
  userInput: FluidLiteArkUserInput,
): Promise<FluidLiteArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `FluidLite-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}` + '_' + 'gov'

  const wrapper = validateAddress(
    config.protocolSpecific.fluid.lite[userInput.token.symbol].wrapper,
    'Fluid Lite wrapper',
  )
  const vault = validateAddress(
    config.protocolSpecific.fluid.lite[userInput.token.symbol].vault,
    'Fluid Lite vault',
  )
  const weth = validateAddress(config.tokens.weth, 'WETH')
  const steth = validateAddress(config.tokens.steth, 'STETH')
  const withdrawalQueue = validateAddress(
    config.protocolSpecific.fluid.lite[userInput.token.symbol].withdrawalQueue,
    'Fluid Lite withdrawal queue',
  )

  // Create and validate ark details

  const arkDetails = {
    protocol: 'Fluid',

    type: 'Lite',

    asset: userInput.token.address,

    marketAsset: userInput.token.address,

    pool: vault,

    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'FluidLite ark details')

  return (await hre.ignition.deploy(createFluidLiteArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        wrapper,
        vault,
        weth,
        steth,
        withdrawalQueue,
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
  })) as FluidLiteArkContracts
}
