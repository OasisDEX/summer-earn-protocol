import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createMapleInstitutionalArkModule,
  MapleInstitutionalArkContracts,
} from '../../ignition/modules/arks/maple-institutional-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateAddress, validateArkDetails, getProtocolConfig } from '../helpers/validation'

export async function deployMapleInstitutionalArk(config: BaseConfig, arkParams?: BaseArkParams) {
  console.log(kleur.green().bold('Starting MapleInstitutionalArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedMapleInstitutionalArk = await deployMapleInstitutionalArkContract(
      config,
      userInput,
    )
    return { ark: deployedMapleInstitutionalArk.mapleInstitutionalArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<BaseArkParams> {
  const mapleConfig = getProtocolConfig(config, 'mapleInstitutional')
  const mapleVaults = []
  if (!mapleConfig) {
    throw new Error('No Maple Institutional vaults found in the configuration.')
  }
  for (const token in mapleConfig.pools) {
    for (const vaultName in mapleConfig.pools[token as Token]) {
      const vaultId = mapleConfig.pools[token as Token].pool
      mapleVaults.push({
        title: `${token.toUpperCase()} - Maple Institutional (${vaultName})`,
        value: { token, vaultId, vaultName },
      })
    }
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'vaultSelection',
      message: 'Select a Maple Institutional vault:',
      choices: mapleVaults,
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
    fleetName: fleetDefinition.fleetName,
    version: 1,
  }

  return aggregatedData
}

async function confirmDeployment(userInput: BaseArkParams, config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployMapleInstitutionalArkContract(
  config: BaseConfig,
  userInput: BaseArkParams,
): Promise<MapleInstitutionalArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `MapleInstitutional-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}` + '_' + 'gov'

  const protocol = `MapleInstitutional`

  const mapleVaultAddress = validateAddress(
    getProtocolConfig(config, 'mapleInstitutional').pools[userInput.token.symbol].pool,
    'Maple Institutional Vault',
  )

  // Create and validate ark details

  const arkDetails = {
    protocol: protocol,
    type: 'MapleInstitutional',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: mapleVaultAddress,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields

  validateArkDetails(arkDetails, 'Maple Institutional ark details')

  return (await hre.ignition.deploy(createMapleInstitutionalArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        vault: mapleVaultAddress,
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
  })) as MapleInstitutionalArkContracts
}
