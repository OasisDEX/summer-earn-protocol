import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address } from 'viem'
import {
  createERC4626ArkModule,
  ERC4626ArkContracts,
} from '../../ignition/modules/arks/erc4626-ark'
import { BaseConfig, Tokens, TokenType } from '../../types/config-types'
import { HUNDRED_PERCENT, MAX_UINT256_STRING } from '../common/constants'
import { getConfigByNetwork } from '../helpers/config-handler'
import { handleDeploymentId } from '../helpers/deployment-id-handler'
import { getChainId } from '../helpers/get-chainid'
import { continueDeploymentCheck } from '../helpers/prompt-helpers'

interface ERC4626VaultInfo {
  token: Tokens
  vaultId: string
  vaultName: string
}

interface ERC4626ArkUserInput {
  vaultSelection: ERC4626VaultInfo
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  token: { address: Address; symbol: Tokens }
  vaultId: string
  vaultName: string
}

export async function deployERC4626Ark() {
  const config = getConfigByNetwork(hre.network.name)

  console.log(kleur.green().bold('Starting ERC4626Ark deployment process...'))

  const userInput = await getUserInput(config)

  if (await confirmDeployment(userInput)) {
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
    for (const vaultName in config.protocolSpecific.erc4626[token as Tokens]) {
      const vaultId = config.protocolSpecific.erc4626[token as TokenType][vaultName]
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
  const tokenAddress = config.tokens[selectedVault.token as TokenType]

  const aggregatedData = {
    ...responses,
    token: { address: tokenAddress, symbol: selectedVault.token },
    vaultId: selectedVault.vaultId,
    vaultName: selectedVault.vaultName,
  }

  return aggregatedData
}

async function confirmDeployment(userInput: ERC4626ArkUserInput) {
  console.log(kleur.cyan().bold('\nSummary of collected values:'))
  console.log(kleur.yellow(`Vault ID               : ${userInput.vaultId}`))
  console.log(kleur.yellow(`Token                  : ${userInput.token}`))
  console.log(kleur.yellow(`Deposit Cap            : ${userInput.depositCap}`))
  console.log(kleur.yellow(`Max Rebalance Outflow  : ${userInput.maxRebalanceOutflow}`))
  console.log(kleur.yellow(`Max Rebalance Inflow   : ${userInput.maxRebalanceInflow}`))

  return await continueDeploymentCheck()
}

async function deployERC4626ArkContract(
  config: BaseConfig,
  userInput: ERC4626ArkUserInput,
): Promise<ERC4626ArkContracts> {
  const chainId = getChainId()
  const deploymentId = await handleDeploymentId(chainId)
  const name = `ERC4626-${userInput.vaultName}-${userInput.token.symbol}-${chainId}`

  return (await hre.ignition.deploy(createERC4626ArkModule(name), {
    parameters: {
      [name]: {
        vault: userInput.vaultId,
        arkParams: {
          name: name,
          details: JSON.stringify({
            protocol: userInput.vaultName,
            type: 'ERC4626',
            asset: userInput.token.address,
            marketAsset: userInput.token.address,
            pool: userInput.vaultId,
            chainId: chainId,
          }),
          accessManager: config.deployedContracts.core.protocolAccessManager.address as Address,
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
