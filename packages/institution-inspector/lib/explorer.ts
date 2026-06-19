import { CHAIN_ID_TO_EXPLORER } from '@/config/chains'

export function explorerAddressUrl(chainId: number, address: string): string | undefined {
  const base = CHAIN_ID_TO_EXPLORER[chainId]
  return base ? `${base}/address/${address}` : undefined
}

export function shortAddress(address: string): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`
}
