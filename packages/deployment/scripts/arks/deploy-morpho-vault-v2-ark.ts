import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createMorphoVaultV2ArkModule,
  MorphoVaultV2ArkContracts,
} from '../../ignition/modules/arks/morpho-vault-v2-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateArkDetails, validateVaultName } from '../helpers/validation'

export interface MorphoVaultV2ArkUserInput extends BaseArkParams {
  vaultId: string
  vaultName: string
}

export async function deployMorphoVaultV2Ark(
  config: BaseConfig,
  arkParams?: MorphoVaultV2ArkUserInput,
) {
  console.log(kleur.green().bold('Starting MorphoVaultV2Ark deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedMorphoVaultV2Ark = await deployMorphoVaultV2ArkContract(config, userInput)
    return { ark: deployedMorphoVaultV2Ark.morphoVaultV2Ark }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<MorphoVaultV2ArkUserInput> {
  // Extract Morpho V2 vaults from the configuration
  const morphoVaultsV2 = []
  if (!config.protocolSpecific.morpho.vaults_v2) {
    throw new Error('No Morpho V2 vaults found in the configuration.')
  }
  for (const token in config.protocolSpecific.morpho.vaults_v2) {
    for (const vaultName in config.protocolSpecific.morpho.vaults_v2[token as Token]) {
      const vaultId = config.protocolSpecific.morpho.vaults_v2[token as Token][vaultName]
      morphoVaultsV2.push({
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
      message: 'Select a Morpho V2 vault:',
      choices: morphoVaultsV2,
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
  userInput: MorphoVaultV2ArkUserInput,
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

async function deployMorphoVaultV2ArkContract(
  config: BaseConfig,
  userInput: MorphoVaultV2ArkUserInput,
): Promise<MorphoVaultV2ArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `MorphoVaultV2-${userInput.vaultName}-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  // Validate vault name format and extract protocol
  validateVaultName(userInput.vaultName, 'Morpho V2 vault name')
  const protocol = 'Morpho' // Hardcoded as it's Morpho V2

  // Create and validate ark details
  const arkDetails = {
    protocol: protocol,
    type: 'MorphoVaultV2',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: userInput.vaultId,
    chainId: chainId,
    vaultName: userInput.vaultName,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'MorphoVaultV2 ark details')

  return (await hre.ignition.deploy(createMorphoVaultV2ArkModule(moduleName), {
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
  })) as MorphoVaultV2ArkContracts
}
