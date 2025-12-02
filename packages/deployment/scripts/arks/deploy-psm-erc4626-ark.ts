import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createPsm3ERC4626ArkModule } from '../../ignition/modules/arks/psm3-erc4626-ark'
import { createPsmLiteERC4626ArkModule } from '../../ignition/modules/arks/psmlite-erc4626-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { ADDRESS_ZERO, HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails } from '../helpers/validation'

export interface PsmERC4626ArkUserInput extends BaseArkParams {
  vaultId: string
  vaultName: string
  vaultToken: string
  psmType: 'psm3' | 'psmlite'
}

export async function deployPsmERC4626Ark(config: BaseConfig, arkParams?: PsmERC4626ArkUserInput) {
  console.log(kleur.green().bold('Starting PSM ERC4626 Ark deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedArk = await deployPsmERC4626ArkContract(config, userInput)
    return { ark: deployedArk.ark }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<PsmERC4626ArkUserInput> {
  // First, let user select PSM type
  const psmTypeResponse = await prompts([
    {
      type: 'select',
      name: 'psmType',
      message: 'Select PSM type:',
      choices: [
        { title: 'PSM3', value: 'psm3' },
        { title: 'PSM Lite', value: 'psmlite' },
      ],
    },
  ])

  // Get available tokens based on PSM type
  const tokens = []
  for (const tokenSymbol in config.tokens) {
    const tokenAddress = config.tokens[tokenSymbol as Token]
    const psmAddress =
      psmTypeResponse.psmType === 'psm3'
        ? config.protocolSpecific.sky.psm3?.[tokenSymbol as Token]
        : config.protocolSpecific.sky.psmLite?.[tokenSymbol as Token]

    if (psmAddress && psmAddress != ADDRESS_ZERO) {
      tokens.push({
        title: tokenSymbol.toUpperCase(),
        value: { address: tokenAddress, symbol: tokenSymbol.toUpperCase() },
      })
    }
  }

  // Get available ERC4626 vaults
  const erc4626Vaults = []
  if (!config.protocolSpecific.erc4626) {
    throw new Error('No ERC4626 vaults found in the configuration.')
  }
  for (const token in config.protocolSpecific.erc4626) {
    for (const vaultName in config.protocolSpecific.erc4626[token as Token]) {
      const vaultId = config.protocolSpecific.erc4626[token as Token][vaultName]
      erc4626Vaults.push({
        title: `${token.toUpperCase()} - ${vaultName}`,
        value: { token, vaultId, vaultName },
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
      type: 'select',
      name: 'vaultSelection',
      message: 'Select an ERC4626 vault:',
      choices: erc4626Vaults,
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
    vaultId: responses.vaultSelection.vaultId,
    vaultName: responses.vaultSelection.vaultName,
    vaultToken: responses.vaultSelection.token,
    psmType: psmTypeResponse.psmType,
    fleetName: fleetDefinition.fleetName,
  }
}

async function confirmDeployment(
  userInput: PsmERC4626ArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`PSM Type              : ${userInput.psmType.toUpperCase()}`))
  console.log(
    kleur.yellow(`Token                 : ${userInput.token.address} (${userInput.token.symbol})`),
  )
  console.log(kleur.yellow(`Vault ID              : ${userInput.vaultId}`))
  console.log(kleur.yellow(`Vault Name            : ${userInput.vaultName}`))
  console.log(kleur.yellow(`USDS                  : ${config.tokens.usds}`))
  console.log(kleur.yellow(`Staked USDS           : ${config.tokens.stakedUsds}`))
  console.log(kleur.yellow(`Deposit Cap           : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow  : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployPsmERC4626ArkContract(config: BaseConfig, userInput: PsmERC4626ArkUserInput) {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `ERC4626-${userInput.psmType.toUpperCase()}-${userInput.vaultName}-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`
  const protocol = userInput.vaultName.split('_')[0]

  const psmAddress = validateAddress(
    userInput.psmType === 'psm3'
      ? config.protocolSpecific.sky.psm3[userInput.token.symbol]
      : config.protocolSpecific.sky.psmLite[userInput.token.symbol],
    'PSM',
  )
  const usdsAddress = validateAddress(config.tokens.usds, 'USDS')
  const stakedUsdsAddress = validateAddress(config.tokens.stakedUsds, 'Staked USDS')
  const vaultAddress = validateAddress(userInput.vaultId, 'ERC4626 Vault')
  if (
    (userInput.vaultToken as Address) != config.tokens.usds &&
    (userInput.vaultToken as Address) != config.tokens.stakedUsds
  ) {
    throw new Error('Vault token must be USDS or Staked USDS')
  }

  const arkDetails = {
    protocol: protocol,
    type: 'PSM-ERC4626',
    asset: userInput.token.address,
    marketAsset: userInput.vaultToken,
    pool: vaultAddress,
    chainId: chainId,
    vaultName: userInput.vaultName,
  }
  validateArkDetails(arkDetails, 'PSM ERC4626 ark details')

  const deploymentParams = {
    parameters: {
      [moduleName]: {
        psm: psmAddress,
        usds: usdsAddress,
        stakedUsds: stakedUsdsAddress,
        vault: vaultAddress,
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
  }

  if (userInput.psmType === 'psm3') {
    return (await hre.ignition.deploy(
      createPsm3ERC4626ArkModule(moduleName),
      deploymentParams,
    )) as {
      ark: any
    }
  } else {
    return (await hre.ignition.deploy(
      createPsmLiteERC4626ArkModule(moduleName),
      deploymentParams,
    )) as {
      ark: any
    }
  }
}
