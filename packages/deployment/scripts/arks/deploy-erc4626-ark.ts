import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createERC4626ArkModule,
  ERC4626ArkContracts,
} from '../../ignition/modules/arks/erc4626-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateArkDetails, validateVaultName } from '../helpers/validation'

export interface ERC4626ArkUserInput extends BaseArkParams {
  vaultId: string
  vaultName: string
}

export async function deployERC4626Ark(config: BaseConfig, arkParams?: ERC4626ArkUserInput) {
  console.log(kleur.green().bold('Starting ERC4626Ark deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedERC4626Ark = await deployERC4626ArkContract(config, userInput)
    return { ark: deployedERC4626Ark.erc4626Ark }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<ERC4626ArkUserInput> {
  // Extract ERC4626 vaults from the configuration
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

  // Set the token address based on the selected vault
  const selectedVault = responses.vaultSelection
  const tokenAddress = config.tokens[selectedVault.token as Token]

  const aggregatedData = {
    depositCap: responses.depositCap,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    maxDepositPercentageOfTVL: responses.maxDepositPercentageOfTVL,
    token: { address: tokenAddress, symbol: selectedVault.token },
    vaultId: selectedVault.vaultId,
    vaultName: selectedVault.vaultName,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

async function confirmDeployment(
  userInput: ERC4626ArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Vault ID               : ${userInput.vaultId}`))
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployERC4626ArkContract(
  config: BaseConfig,
  userInput: ERC4626ArkUserInput,
): Promise<ERC4626ArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `ERC4626-${userInput.vaultName}-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  // Validate vault name format and extract protocol
  validateVaultName(userInput.vaultName, 'ERC4626 vault name')
  let protocol = userInput.vaultName.split('_')[0]
  if (
    protocol === 'Morpho' &&
    userInput.vaultName.split('_').length > 1 &&
    userInput.vaultName.split('_')[1] === 'V2'
  ) {
    protocol = 'Morpho_V2'
  }

  // Create and validate ark details
  const arkDetails = {
    protocol: protocol,
    type: 'ERC4626',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: userInput.vaultId,
    chainId: chainId,
    vaultName: userInput.vaultName,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'ERC4626 ark details')
  return (await hre.ignition.deploy(createERC4626ArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        vault: userInput.vaultId,
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
  })) as ERC4626ArkContracts
}
