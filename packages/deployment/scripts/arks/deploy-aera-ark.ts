import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import { AeraArkContracts, createAeraArkModule } from '../../ignition/modules/arks/aera-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { BaseArkParams } from '../common/ark-deployment'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getFleetConfig } from '../common/fleet-deployment-files-helpers'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'
import { validateArkDetails, validateVaultName } from '../helpers/validation'

export interface AeraArkUserInput extends BaseArkParams {
  provisioner: string
  vaultName: string
}

export async function deployAeraArk(config: BaseConfig, arkParams?: AeraArkUserInput) {
  console.log(kleur.green().bold('Starting AeraArk deployment process...'))

  const userInput = arkParams || (await getUserInput(config))

  if (await confirmDeployment(userInput, config, arkParams != undefined)) {
    const deployedAeraArk = await deployAeraArkContract(config, userInput)
    return { ark: deployedAeraArk.aeraArk }
  } else {
    console.log(kleur.red().bold('Deployment cancelled by user.'))
  }
}

async function getUserInput(config: BaseConfig): Promise<AeraArkUserInput> {
  // Extract Aera provisioners from the configuration
  const provisioners = []
  if (!config.protocolSpecific.aera || !config.protocolSpecific.aera.vaults) {
    throw new Error('No Aera provisioners found in the configuration.')
  }
  for (const token in config.protocolSpecific.aera.vaults) {
    for (const vaultName in config.protocolSpecific.aera.vaults[token as Token]) {
      const provisioner = config.protocolSpecific.aera.vaults[token as Token][vaultName].provisioner
      provisioners.push({
        title: `${token.toUpperCase()} - ${vaultName}`,
        value: { token, provisioner, vaultName },
      })
    }
  }
  const fleetDefinition = await getFleetConfig()
  const responses = await prompts([
    {
      type: 'select',
      name: 'vaultSelection',
      message: 'Select a Aera provisioner:',
      choices: provisioners,
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
    provisioner: selectedVault.provisioner,
    vaultName: selectedVault.vaultName,
    fleetName: fleetDefinition.fleetName,
  }

  return aggregatedData
}

async function confirmDeployment(userInput: AeraArkUserInput, config: BaseConfig, skip: boolean) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Provisioner ID        : ${userInput.provisioner}`))
  console.log(
    kleur.yellow(`Token                  : ${userInput.token.address} - ${userInput.token.symbol}`),
  )
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))
  console.log(kleur.yellow(`Fleet Name             : ${userInput.fleetName}`))

  return skip ? true : await continueDeploymentCheck()
}

async function deployAeraArkContract(
  config: BaseConfig,
  userInput: AeraArkUserInput,
): Promise<AeraArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const arkName = `Aera-${userInput.vaultName}-${userInput.token.symbol}-${chainId}`
  const envLabel = userInput.isBummer ? 'staging_' : ''
  const moduleName = `${envLabel}${userInput.fleetName}_${arkName.replace(/-/g, '_')}`

  // Validate vault name format and extract protocol
  validateVaultName(userInput.vaultName, 'Aera vault name')
  const protocol = userInput.vaultName.split('_')[0]

  const provisionerContract =
    config.protocolSpecific.aera.vaults[userInput.token.symbol][userInput.vaultName].provisioner
  // call provisioner to get MULTI_DEPOSITOR_VAULT() as it's the pool address
  const multiDepositorVault = await hre.viem.getContractAt(
    'IProvisioner' as string,
    provisionerContract,
  )
  const poolAddress = await multiDepositorVault.read.MULTI_DEPOSITOR_VAULT()

  // Create and validate ark details
  const arkDetails = {
    protocol: protocol,
    type: 'Aera',
    asset: userInput.token.address,
    marketAsset: userInput.token.address,
    pool: poolAddress,
    chainId: chainId,
  }

  // Validate the details object to ensure it has the minimal required fields
  validateArkDetails(arkDetails, 'Aera ark details')

  return (await hre.ignition.deploy(createAeraArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        provisioner: userInput.provisioner,
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
  })) as AeraArkContracts
}
