import prodConfig from '../../config/index.json'
import testConfig from '../../config/index.test.json'
import type { BaseConfig } from '../../types/config-types'
import { CHAIN_CONFIG_MAP, RPC_URL_MAP } from '../common/chain-config-map'
import { SupportedChain } from './chain'

export function getChainConfigs(useTestConfig: boolean = false) {
  const config = useTestConfig ? testConfig : prodConfig

  return {
    [SupportedChain.base]: {
      chain: CHAIN_CONFIG_MAP.base,
      config: config.base as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.base as string,
    },
    [SupportedChain.arbitrum]: {
      chain: CHAIN_CONFIG_MAP.arbitrum,
      config: config.arbitrum as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.arbitrum as string,
    },

    [SupportedChain.mainnet]: {
      chain: CHAIN_CONFIG_MAP.mainnet,
      config: config.mainnet as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.mainnet as string,
    },
    [SupportedChain.sonic]: {
      chain: CHAIN_CONFIG_MAP.sonic,
      config: config.sonic as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.sonic as string,
    },
    [SupportedChain.hyperliquid]: {
      chain: CHAIN_CONFIG_MAP.hyperliquid,
      config: config.hyperliquid as unknown as BaseConfig,
      rpcUrl: RPC_URL_MAP.hyperliquid as string,
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
