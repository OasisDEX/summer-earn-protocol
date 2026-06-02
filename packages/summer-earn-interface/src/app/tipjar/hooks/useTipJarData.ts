'use client'

import { useCallback, useRef } from 'react'
import { useQuery } from '@tanstack/react-query'

import type { ChainId } from '@/types'

export interface TipStreamEntry {
  recipient: `0x${string}`
  /** Raw Percentage (18 decimals): 1% = 1e18, 100% = 100e18. */
  allocation: bigint
  lockedUntilEpoch: bigint
}

export interface TipJarFleetEntry {
  address: `0x${string}`
  name: string
  assetSymbol: string
  assetDecimals: number
  pendingShares: bigint
  /** TipJar's redeemable value in this fleet's asset (≈ what a shake distributes). */
  pendingAssets: bigint
}

export interface TipJarInstanceData {
  label: string
  address: `0x${string}`
  paused: boolean
  totalAllocation: bigint
  streams: TipStreamEntry[]
  fleets: TipJarFleetEntry[]
}

interface RawInstance {
  label: string
  address: `0x${string}`
  paused: boolean
  totalAllocation: string
  streams: { recipient: `0x${string}`; allocation: string; lockedUntilEpoch: string }[]
  fleets: {
    address: `0x${string}`
    name: string
    assetSymbol: string
    assetDecimals: number
    pendingShares: string
    pendingAssets: string
  }[]
}

function parseInstance(raw: RawInstance): TipJarInstanceData {
  return {
    label: raw.label,
    address: raw.address,
    paused: raw.paused,
    totalAllocation: BigInt(raw.totalAllocation),
    streams: raw.streams.map((s) => ({
      recipient: s.recipient,
      allocation: BigInt(s.allocation),
      lockedUntilEpoch: BigInt(s.lockedUntilEpoch),
    })),
    fleets: raw.fleets.map((f) => ({
      address: f.address,
      name: f.name,
      assetSymbol: f.assetSymbol,
      assetDecimals: f.assetDecimals,
      pendingShares: BigInt(f.pendingShares),
      pendingAssets: BigInt(f.pendingAssets),
    })),
  }
}

/**
 * Loads TipJar config + pending shakeable amounts for a single chain. One call
 * per chain section so each chain loads/refreshes independently. `refresh()`
 * bypasses the server's short-lived cache (used after a successful shake).
 */
export function useTipJarData(chainId: ChainId) {
  const bust = useRef(false)

  const query = useQuery({
    queryKey: ['tipjar', chainId],
    queryFn: async () => {
      const refresh = bust.current
      bust.current = false
      const res = await fetch(
        `/api/tipjar?chainId=${encodeURIComponent(chainId)}${refresh ? '&refresh=true' : ''}`,
        { cache: 'no-store' },
      )
      if (!res.ok) {
        let msg = `Failed to load TipJar data: ${res.status}`
        try {
          const body = await res.json()
          if (body?.error) msg = body.error
        } catch {
          // ignore non-JSON error bodies
        }
        throw new Error(msg)
      }
      const data = (await res.json()) as { instances: RawInstance[] }
      return data.instances.map(parseInstance)
    },
    staleTime: 20 * 1000,
    refetchOnWindowFocus: false,
  })

  const refresh = useCallback(() => {
    bust.current = true
    return query.refetch()
  }, [query])

  return {
    instances: query.data ?? [],
    loading: query.isLoading,
    error: (query.error as Error) ?? null,
    refresh,
  }
}
