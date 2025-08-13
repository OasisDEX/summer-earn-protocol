import { arbitrum, base, mainnet, optimism, sonic, unichain } from 'viem/chains'

// Centralized RPC URL mapping
export const RPC_URL_MAP = {
  mainnet: process.env.MAINNET_RPC_URL,
  base: process.env.BASE_RPC_URL,
  arbitrum: process.env.ARBITRUM_RPC_URL,
  sonic: process.env.SONIC_RPC_URL,
  unichain: process.env.UNICHAIN_RPC_URL,
  optimism: process.env.OPTIMISM_RPC_URL,
}

// Standard chain mapping
export const CHAIN_CONFIG_MAP = {
  mainnet,
  base,
  arbitrum,
  sonic: sonic,
  unichain,
  optimism,
}

export const CHAIN_MAP_BY_ID = Object.fromEntries(
  Object.values(CHAIN_CONFIG_MAP).map((chain) => [chain.id, chain]),
)
