'use client'
import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'

import type { ChainName, DvnInfo } from '../lib/types'

const METADATA_URL = 'https://metadata.layerzero-api.com/v1/metadata'

const META_CHAIN_KEY: Record<ChainName, string[]> = {
  mainnet: ['ethereum', 'ethereum-mainnet'],
  base: ['base', 'base-mainnet'],
  arbitrum: ['arbitrum', 'arbitrum-mainnet'],
  sonic: ['sonic', 'sonic-mainnet'],
  hyperliquid: ['hyperliquid', 'hyperliquid-mainnet'],
  sepolia: ['sepolia', 'ethereum-testnet-sepolia'], // testnet — no LZ OApp config, present for type completeness
}

export interface DvnMetadata {
  byChain: Record<ChainName, Record<string /* lowercased address */, DvnInfo>>
}

interface RawDvn {
  canonicalName?: string
  deprecated?: boolean
  lzReadCompatible?: boolean
}

export function useDvnMetadata() {
  return useQuery<DvnMetadata>({
    queryKey: ['lz-dvn-metadata'],
    staleTime: 24 * 60 * 60 * 1000,
    gcTime: 7 * 24 * 60 * 60 * 1000,
    queryFn: async () => {
      const res = await fetch(METADATA_URL)
      if (!res.ok) throw new Error(`metadata fetch failed: ${res.status}`)
      const raw = (await res.json()) as Record<string, { dvns?: Record<string, RawDvn> }>

      const byChain = {} as DvnMetadata['byChain']
      for (const chainName of Object.keys(META_CHAIN_KEY) as ChainName[]) {
        const candidates = META_CHAIN_KEY[chainName]
        const matched = candidates.map((k) => raw[k]).find(Boolean)
        const dvns = matched?.dvns ?? {}
        const entries: Record<string, DvnInfo> = {}
        for (const [addr, info] of Object.entries(dvns)) {
          const lower = addr.toLowerCase()
          entries[lower] = {
            address: addr as Address,
            canonicalName: info.canonicalName ?? 'Unknown DVN',
            deprecated: info.deprecated ?? false,
            lzReadCompatible: info.lzReadCompatible,
          }
        }
        byChain[chainName] = entries
      }
      return { byChain }
    },
  })
}

export function lookupDvn(
  metadata: DvnMetadata | undefined,
  chain: ChainName,
  address: string | null | undefined,
): DvnInfo | null {
  if (!metadata || !address) return null
  return metadata.byChain[chain]?.[address.toLowerCase()] ?? null
}
