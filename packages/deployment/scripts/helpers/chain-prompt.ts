import dotenv from 'dotenv'
import prompts from 'prompts'
import { Chain, Hex } from 'viem'
import { arbitrum, base, mainnet } from 'viem/chains'
import config from '../../config/index.json'

dotenv.config()

const PRIVATE_KEY = process.env.PRIVATE_KEY as Hex

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

export const chainConfigs = {
  base: {
    chain: base,
    config: config.base,
    rpcUrl: process.env.BASE_RPC_URL as string,
  },
  arbitrum: {
    chain: arbitrum,
    config: config.arbitrum,
    rpcUrl: process.env.ARBITRUM_RPC_URL as string,
  },
  mainnet: {
    chain: mainnet,
    config: config.mainnet,
    rpcUrl: process.env.MAINNET_RPC_URL as string,
  },
} as const

export type ChainName = keyof typeof chainConfigs

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
    value: { name: key, ...chainConfigs[key as ChainName] },
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

  return {
    ...selectedChain,
  }
}

export async function promptForPeerChain(currentChain: ChainName): Promise<{
  name: ChainName
  config: ChainConfig
  endpointId: string
}> {
  const peerChainOptions = Object.entries(chainConfigs)
    .filter(([key]) => key !== currentChain)
    .map(([key, value]) => ({
      title: key,
      value: {
        name: key as ChainName,
        config: value.config,
        endpointId: value.config.common.layerZero.eID,
      },
    }))

  const { selectedPeerChain } = await prompts({
    type: 'select',
    name: 'selectedPeerChain',
    message: 'Which chain would you like to add as a peer?',
    choices: peerChainOptions,
  })

  if (!selectedPeerChain) throw new Error('No peer chain selected')

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Please confirm you want to add ${selectedPeerChain.name} as a peer`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  return selectedPeerChain
}

export async function promptForTargetChain(currentChain: ChainName): Promise<{
  name: ChainName
  config: ChainConfig
  endpointId: string
}> {
  const targetChainOptions = Object.entries(chainConfigs)
    .filter(([key]) => key !== currentChain)
    .map(([key, value]) => ({
      title: key,
      value: {
        name: key as ChainName,
        config: value.config,
        endpointId: value.config.common.layerZero.eID,
      },
    }))

  const { selectedTargetChain } = await prompts({
    type: 'select',
    name: 'selectedTargetChain',
    message: 'Which chain would you like to set as the target?',
    choices: targetChainOptions,
  })

  if (!selectedTargetChain) throw new Error('No target chain selected')

  const { confirmed } = await prompts({
    type: 'confirm',
    name: 'confirmed',
    message: `Please confirm you want to set ${selectedTargetChain.name} as the target chain`,
    initial: false,
  })

  if (!confirmed) {
    throw new Error('Operation cancelled by user')
  }

  return selectedTargetChain
}
