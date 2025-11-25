import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createSiloManagedVaultArkModule,
  SiloManagedVaultArkContracts,
} from '../../ignition/modules/arks/silo-managed-vault-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateArkDetails } from '../helpers/validation'

export interface SiloManagedVaultArkUserInput extends BaseArkParams {
  vaultId: string
  vaultName: string
}

export async function deploySiloManagedVaultArk(
  config: BaseConfig,
  arkParams?: SiloManagedVaultArkUserInput,
) {
  console.log(kleur.green().bold('Starting SiloManagedVaultArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedSiloManagedVaultArk = await deploySiloManagedVaultArkContract(config, userInput)
    return { ark: deployedSiloManagedVaultArk.siloManagedVaultArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<SiloManagedVaultArkUserInput> {
  // Extract Silo vaults from the configuration
  const siloVaults = []
  if (!config.protocolSpecific.silo || !config.protocolSpecific.silo.vaults) {
    throw new Error('No Silo vaults found in the configuration.')
  }
  for (const token in config.protocolSpecific.silo.vaults) {
    for (const vaultName in config.protocolSpecific.silo.vaults[token as Token]) {
      const vaultId = config.protocolSpecific.silo.vaults[token as Token][vaultName]
      siloVaults.push({
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
      message: 'Select a Silo vault:',
      choices: siloVaults,
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
  userInput: SiloManagedVaultArkUserInput,
  config: BaseConfig,
  skip: boolean,
) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Vault ID              : ${userInput.vaultId}`))
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deploySiloManagedVaultArkContract(
  config: BaseConfig,
  userInput: SiloManagedVaultArkUserInput,
): Promise<SiloManagedVaultArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `SiloManagedVault-${userInput.vaultName}-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const protocol = 'Silo'

  // Create and validate ark details

  const arkDetails = {
    protocol: protocol,
    type: 'SiloManagedVault',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: userInput.vaultId,
    chainId: chainId,
    vaultName: userInput.vaultName,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'SiloManagedVault ark details')

  return (await hre.ignition.deploy(createSiloManagedVaultArkModule(moduleName), {
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
  })) as SiloManagedVaultArkContracts
}
