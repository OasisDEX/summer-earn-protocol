import dotenv from 'dotenv'
import hre from 'hardhat'
import prompts from 'prompts'
import { Chain } from 'viem'
import { chainConfigs, ChainName } from './chain-configs'

dotenv.config()

// Define config types
export type ChainConfig = {
  deployedContracts: {
    gov: {
      summerGovernor: { address: string }
      summerToken: { address: string }
      timelock: { address: string }
      protocolAccessManager: { address: string }
    }
    core: {
      tipJar: { address: string }
      raft: { address: string }
      configurationManager: { address: string }
      harborCommand: { address: string }
    }
  }
  common: {
    layerZero: {
      eID: string
      lzEndpoint: string
    }
    treasury: string
    tipRate: string
  }
}

export interface ChainSetup {
  name: ChainName
  config: ChainConfig
  chain: Chain
  rpcUrl: string
}

/**
 * Prompts the user for the chain selection (manual prompt).
 */
export async function promptForChain(
  message = 'Which chain would you like to execute this operation on?',
): Promise<ChainSetup> {
  const chainOptions = Object.keys(chainConfigs).map((key) => ({
    title: key,
    value: { name: key as ChainName, ...chainConfigs[key as ChainName] },
  }))

  const { selectedChain } = await prompts({
    type: 'select',
    name: 'selectedChain',
    message,
    choices: chainOptions,
  })

  if (!selectedChain) throw new Error('No chain selected')

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Please confirm you want to execute on ${selectedChain.name}`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  return selectedChain
}

/**
 * Automatically infers the chain from hre and asks the user to confirm.
 *
 * Instead of prompting the user with a list of chains, this function uses the detected
 * chainId (from hre.network.config.chainId) to look up its configuration from chainConfigs.
 */
export async function promptForChainFromHre(
  message = 'Do you want to execute this operation on the current network?',
): Promise<ChainSetup> {
  // Get chain id from Hardhat runtime environment.
  const detectedChainId = hre.network.config.chainId
  // Find the matching chain config by comparing the chain.id value.
  const entry = Object.entries(chainConfigs).find(([_, config]) => {
    return config.chain.id === detectedChainId
  })

  if (!entry) {
    throw new Error(`Chain with id ${detectedChainId} not found in chainConfigs`)
  }

  const [chainName, config] = entry
  // Build the ChainSetup object (same structure returned by promptForChain).
  const chainSetup: ChainSetup = { name: chainName as ChainName, ...config }

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `${message} ${chainSetup.name} (chainId ${detectedChainId})?`,
    initial: true,
  })
  if (!confirmed) throw new Error('Operation cancelled by user')

  return chainSetup
}

export async function promptForTargetChain(currentChain: ChainName): Promise<ChainSetup> {
  const chainOptions = Object.entries(chainConfigs)
    .filter(([key]) => key !== currentChain)
    .map(([key]) => ({
      title: key,
      value: { name: key as ChainName, ...chainConfigs[key as ChainName] },
    }))

  const { selectedChain } = await prompts({
    type: 'select',
    name: 'selectedChain',
    message: 'Which chain would you like to set as the target?',
    choices: chainOptions,
  })

  if (!selectedChain) throw new Error('No target chain selected')

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Please confirm you want to set ${selectedChain.name} as the target chain`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  return selectedChain
}
