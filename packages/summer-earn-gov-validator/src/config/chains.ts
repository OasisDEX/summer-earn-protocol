import { Address } from 'viem'

export interface ChainTheme {
  name: string
  color: string // primary brand hex
  bg: string // background with opacity (Tailwind class)
  border: string // border with opacity (Tailwind class)
  text: string // text color (Tailwind class)
  icon: string // material symbol name
}

export const CHAIN_THEMES: Record<string, ChainTheme> = {
  mainnet: {
    name: 'Mainnet',
    color: '#94a3b8',
    bg: 'bg-chain-mainnet/20',
    border: 'border-chain-mainnet/30',
    text: 'text-chain-mainnet',
    icon: 'hub',
  },
  base: {
    name: 'Base',
    color: '#0052FF',
    bg: 'bg-chain-base/20',
    border: 'border-chain-base/30',
    text: 'text-chain-base',
    icon: 'layers',
  },
  arbitrum: {
    name: 'Arbitrum',
    color: '#28a0f0',
    bg: 'bg-chain-arbitrum/20',
    border: 'border-chain-arbitrum/30',
    text: 'text-chain-arbitrum',
    icon: 'swap_calls',
  },
  sonic: {
    name: 'Sonic',
    color: '#00e5ff',
    bg: 'bg-chain-sonic/20',
    border: 'border-chain-sonic/30',
    text: 'text-chain-sonic',
    icon: 'bolt',
  },
  hyperliquid: {
    name: 'Hyperliquid',
    color: '#00ffa3',
    bg: 'bg-chain-hyperliquid/20',
    border: 'border-chain-hyperliquid/30',
    text: 'text-chain-hyperliquid',
    icon: 'speed',
  },
}

export const getChainTheme = (network?: string): ChainTheme => {
  if (!network) return CHAIN_THEMES.base // Default to base as requested
  const normalized = network.toLowerCase()
  return CHAIN_THEMES[normalized] || CHAIN_THEMES.base
}
// --- Constants & Config ---

export const HUB_GOVERNOR_ADDRESS = '0x4cEeE1b6289624d381383C1Bb42B118d5f2c3274' as Address
export const HUB_TOKEN_ADDRESS = '0x7cC488F2681cFC2A5E8A00184bfA94ea6d520D1c' as Address
export const HUB_CHAIN_ID = '8453'

export const CHAINS = [
  { id: '8453', name: 'Base', key: 'base', eID: '30184', tenderlyId: '8453' },
  { id: '42161', name: 'Arbitrum', key: 'arbitrum', eID: '30110', tenderlyId: '42161' },
  { id: '1', name: 'Ethereum', key: 'mainnet', eID: '30101', tenderlyId: '1' },
  { id: '146', name: 'Sonic', key: 'sonic', eID: '30332', tenderlyId: '146' },
  { id: '999', name: 'HyperLiquid', key: 'hyperliquid', eID: '30367', tenderlyId: null },
]
export function getChainNameById(id: string) {
  return CHAINS.find((chain) => chain.id === id)?.name || 'Unknown'
}

export function getChainIdByName(name: string) {
  return CHAINS.find((chain) => chain.name === name)?.id || 'Unknown'
}

export function getChainEidByName(name: string) {
  return CHAINS.find((chain) => chain.name === name)?.eID || 'Unknown'
}
