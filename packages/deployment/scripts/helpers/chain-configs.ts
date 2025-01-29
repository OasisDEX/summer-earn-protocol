import { arbitrum, base, mainnet } from 'viem/chains'
import config from '../../config/index.json'

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
