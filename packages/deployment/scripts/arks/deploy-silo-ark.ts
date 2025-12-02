import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { createSiloArkModule, SiloArkContracts } from '../../ignition/modules/arks/silo-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateArkDetails } from '../helpers/validation'

export interface SiloArkUserInput extends BaseArkParams {
  siloId: string
  siloName: string
}

export async function deploySiloArk(config: BaseConfig, arkParams?: SiloArkUserInput) {
  console.log(kleur.green().bold('Starting SiloArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedSiloArk = await deploySiloArkContract(config, userInput)
    return { ark: deployedSiloArk.siloArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<SiloArkUserInput> {
  // Extract Silo vaults from the configuration
  const siloVaults = []
  if (!config.protocolSpecific.silo || !config.protocolSpecific.silo.pools) {
    throw new Error('No Silo vaults found in the configuration.')
  }
  for (const token in config.protocolSpecific.silo.pools) {
    for (const vaultName in config.protocolSpecific.silo.pools[token as Token]) {
      const vaultId = config.protocolSpecific.silo.pools[token as Token][vaultName]
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
    siloId: selectedVault.vaultId,
    siloName: selectedVault.vaultName,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

async function confirmDeployment(userInput: SiloArkUserInput, config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Silo ID               : ${userInput.siloId}`))
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deploySiloArkContract(
  config: BaseConfig,
  userInput: SiloArkUserInput,
): Promise<SiloArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Silo-${userInput.siloName}-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  const protocol = 'Silo'

  // Create and validate ark details
  const arkDetails = {
    protocol: protocol,
    type: 'Silo',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: userInput.siloId,
    chainId: chainId,
    vaultName: userInput.siloName,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'Silo ark details')

  return (await hre.ignition.deploy(createSiloArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        silo: userInput.siloId,
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
  })) as SiloArkContracts
}
