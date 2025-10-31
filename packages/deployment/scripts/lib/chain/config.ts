import { arbitrum, base, mainnet, optimism, sonic } from 'viem/chains'
import { defineChain } from 'viem'
import prodConfig from '../../../config/index.json'
import testConfig from '../../../config/index.test.json'
import type { BaseConfig } from '../../../types/config-types'

// Unichain chain definition (not available in viem/chains)
const unichain = defineChain({
  id: 130,
  name: 'Unichain',
  nativeCurrency: {
    decimals: 18,
    name: 'Ethereum',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.unichain.org'],
    },
  },
  blockExplorers: {
    default: {
      name: 'Uniscan',
      url: 'https://uniscan.xyz',
    },
  },
})

// Centralized RPC URL mapping
export const RPC_URL_MAP = {
  mainnet: process.env.MAINNET_RPC_URL,
  base: process.env.BASE_RPC_URL,
  arbitrum: process.env.ARBITRUM_RPC_URL,
  sonic: process.env.SONIC_RPC_URL,
  optimism: process.env.OPTIMISM_RPC_URL,
  unichain: process.env.UNICHAIN_RPC_URL,
}

// Standard chain mapping
export const CHAIN_CONFIG_MAP = {
  mainnet,
  base,
  arbitrum,
  sonic: sonic,
  optimism,
  unichain,
}

export const CHAIN_MAP_BY_ID = Object.fromEntries(
  Object.values(CHAIN_CONFIG_MAP).map((chain) => [chain.id, chain]),
)

export function getChainConfigs(useTestConfig: boolean = false) {
  const config = useTestConfig ? testConfig : prodConfig

  return {
    base: {
      chain: CHAIN_CONFIG_MAP.base,
      config: config.base as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.base as string,
    },
    arbitrum: {
      chain: CHAIN_CONFIG_MAP.arbitrum,
      config: config.arbitrum as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.arbitrum as string,
    },
    mainnet: {
      chain: CHAIN_CONFIG_MAP.mainnet,
      config: config.mainnet as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.mainnet as string,
    },
    sonic: {
      chain: CHAIN_CONFIG_MAP.sonic,
      config: config.sonic as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.sonic as string,
    },
    optimism: {
      chain: CHAIN_CONFIG_MAP.optimism,
      config: config.optimism as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.optimism as string,
    },
    unichain: {
      chain: CHAIN_CONFIG_MAP.unichain,
      config: config.unichain as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.unichain as string,
    },
  } as const
}

export function getChainConfigByChainName(chainName: ChainName, useTestConfig: boolean = false) {
  const configs = getChainConfigs(useTestConfig)
  const config = configs[chainName]
  if (!config) throw new Error(`Chain config not found for ${chainName}`)
  return config
}

export function getChainConfigByChainId(chainId: number, useTestConfig: boolean = false) {
  const configs = getChainConfigs(useTestConfig)
  const chainEntries = Object.entries(configs)

  const match = chainEntries.find(([_, config]) => config.chain.id === chainId)
  if (!match) {
    throw new Error(`Chain config not found for chain ID: ${chainId}`)
  }

  const [chainName, chainConfig] = match
  return { chainName: chainName as ChainName, chainConfig }
}

export type ChainName = keyof ReturnType<typeof getChainConfigs>
