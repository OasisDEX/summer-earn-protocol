import { BaseConfig, Config, SupportedNetworks } from '../types/config-types'
import allConfigs from './index.json'

type DstId = '30184' | '30110' | '30332' | '30101'

const dstEidToChainIdMap: Record<DstId, SupportedNetworks> = {
  '30184': SupportedNetworks.BASE,
  '30110': SupportedNetworks.ARBITRUM,
  '30332': SupportedNetworks.SONIC,
  '30101': SupportedNetworks.MAINNET,
}

const config = {
  [SupportedNetworks.MAINNET]: { ...allConfigs.base } as unknown as BaseConfig,
  [SupportedNetworks.BASE]: { ...allConfigs.base } as unknown as BaseConfig,
  [SupportedNetworks.ARBITRUM]: { ...allConfigs.arbitrum } as unknown as BaseConfig,
  [SupportedNetworks.SONIC]: { ...allConfigs.sonic } as unknown as BaseConfig,
} as Config

export { config, dstEidToChainIdMap, type DstId }
