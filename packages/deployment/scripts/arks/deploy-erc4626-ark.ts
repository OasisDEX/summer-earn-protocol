import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createERC4626ArkModule,
  ERC4626ArkContracts,
} from '../../ignition/modules/arks/erc4626-ark'
import { BaseConfig, Token } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

export interface ERC4626ArkUserInput {
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  token: { address: Address; symbol: Token }
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
  ])

  // Set the token address based on the selected vault
  const selectedVault = responses.vaultSelection
  const tokenAddress = config.tokens[selectedVault.token as Token]

  const aggregatedData = {
    depositCap: responses.depositCap,
    maxRebalanceOutflow: responses.maxRebalanceOutflow,
    maxRebalanceInflow: responses.maxRebalanceInflow,
    token: { address: tokenAddress, symbol: selectedVault.token },
    vaultId: selectedVault.vaultId,
    vaultName: selectedVault.vaultName,
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
  const moduleName = arkName.replace(/-/g, '_')

  const protocol = userInput.vaultName.split('_')[0]

  return (await hre.ignition.deploy(createERC4626ArkModule(moduleName), {
    parameters: {
      [moduleName]: {
        vault: userInput.vaultId,
        arkParams: {
          name: arkName,
          details: JSON.stringify({
            protocol: protocol,
            type: 'ERC4626',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: userInput.vaultId,
            chainId: chainId,
            vaultName: userInput.vaultName,
          }),
          accessManager: config.deployedContracts.gov.protocolAccessManager.address as Address,
          configurationManager: config.deployedContracts.core.configurationManager
            .address as Address,
          asset: userInput.token.address,
          depositCap: userInput.depositCap,
          maxRebalanceOutflow: userInput.maxRebalanceOutflow,
          maxRebalanceInflow: userInput.maxRebalanceInflow,
          requiresKeeperData: false,
          maxDepositPercentageOfTVL: HUNDRED_PERCENT,
        },
      },
    },
    deploymentId,
  })) as ERC4626ArkContracts
}
