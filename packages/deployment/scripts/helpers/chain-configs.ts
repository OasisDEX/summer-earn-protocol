import { arbitrum, base, mainnet } from 'viem/chains'
import prodConfig from '../../config/index.json'
import testConfig from '../../config/index.test.json'
import type { BaseConfig } from '../../types/config-types'

export function getChainConfigs(useTestConfig: boolean = false) {
  const config = useTestConfig ? testConfig : prodConfig

  return {
    base: {
      chain: base,
      config: config.base as unknown as BaseConfig,
      rpcUrl: process.env.BASE_RPC_URL as string,
    },
    arbitrum: {
      chain: arbitrum,
      config: config.arbitrum as unknown as BaseConfig,
      rpcUrl: process.env.ARBITRUM_RPC_URL as string,
    },
    mainnet: {
      chain: mainnet,
      config: config.mainnet as unknown as BaseConfig,
      rpcUrl: process.env.MAINNET_RPC_URL as string,
    },
  } as const
}

export function getChainConfigByChainId(chainId: number, useTestConfig: boolean = false) {
  const configs = getChainConfigs(useTestConfig)
  const chainEntries = Object.entries(configs)

  const match = chainEntries.find(([_, config]) => config.chain.id === chainId)
  if (!match) return undefined

  const [chainName, chainConfig] = match
  return { chainName: chainName as ChainName, chainConfig }
}

export type ChainName = keyof ReturnType<typeof getChainConfigs>
