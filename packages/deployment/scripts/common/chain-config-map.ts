import { defineChain } from 'viem'
import { arbitrum, base, mainnet, sonic } from 'viem/chains'
import { SupportedChain } from '../helpers/chain'

export const hyperliquid = defineChain({
  id: 999,
  name: 'Hyperliquid',
  nativeCurrency: { name: 'Hyperliquid', symbol: 'HYPE', decimals: 18 },
  rpcUrls: {
    default: { http: ['https://rpc.hypurrscan.io'] },
  },
  blockExplorers: {
    default: {
      name: 'Hyperliquid Explorer',
      url: 'https://hyperevmscan.io/',
    },
  },
  testnet: false,
})

// Centralized RPC URL mapping
export const RPC_URL_MAP = {
  [SupportedChain.mainnet]: process.env.MAINNET_RPC_URL,
  [SupportedChain.base]: process.env.BASE_RPC_URL,
  [SupportedChain.arbitrum]: process.env.ARBITRUM_RPC_URL,
  [SupportedChain.sonic]: process.env.SONIC_RPC_URL,
  [SupportedChain.hyperliquid]: process.env.HYPERLIQUID_RPC_URL,
}

// Standard chain mapping
export const CHAIN_CONFIG_MAP = {
  [SupportedChain.mainnet]: mainnet,
  [SupportedChain.base]: base,
  [SupportedChain.arbitrum]: arbitrum,
  [SupportedChain.sonic]: sonic,
  [SupportedChain.hyperliquid]: hyperliquid,
}

export const CHAIN_MAP_BY_ID = Object.fromEntries(
  Object.values(CHAIN_CONFIG_MAP).map((chain) => [chain.id, chain]),
)
