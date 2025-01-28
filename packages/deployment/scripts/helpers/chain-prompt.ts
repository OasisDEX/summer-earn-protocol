import dotenv from 'dotenv'
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
