'use client'

import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'
import { usePublicClient } from 'wagmi'

import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { harborCommandAbi } from '@/abis/HarborCommand'
import { HARBOR_COMMAND_ADDRESSES, lookupFeedForAsset } from '@/config/addresses'
import type { ChainId } from '@/types/chain'

export interface ActiveFleet {
  address: Address
  name: string
  symbol: string
  decimals: number
  asset: {
    address: Address
    symbol: string
    decimals: number
  }
  /** Feed address from FEED_BY_ASSET_ADDRESS, or undefined if no mapping exists. */
  feed?: Address
}

// Discover all active FleetCommanders for the chain. Two-stage read:
//   1) HarborCommand.getActiveFleetCommanders() — addresses.
//   2) multicall(per fleet) — name, symbol, decimals, asset address, then
//      multicall(per asset) — symbol, decimals.
// Both results combined and cached forever — the active set churns rarely,
// and a manual refetch via the returned function covers the rare add/remove.
export function useActiveFleets(chainId: ChainId) {
  const client = usePublicClient({ chainId: Number(chainId) })
  const harbor = HARBOR_COMMAND_ADDRESSES[chainId]

  return useQuery({
    queryKey: ['dca', 'active-fleets', chainId],
    enabled: Boolean(client),
    staleTime: Number.POSITIVE_INFINITY,
    queryFn: async (): Promise<ActiveFleet[]> => {
      if (!client) throw new Error('Public client unavailable')

      const fleetAddresses = (await client.readContract({
        address: harbor,
        abi: harborCommandAbi,
        functionName: 'getActiveFleetCommanders',
      })) as readonly Address[]

      if (fleetAddresses.length === 0) return []

      // Stage 1: per-fleet metadata.
      const fleetCalls = fleetAddresses.flatMap((address) => [
        { address, abi: fleetCommanderAbi, functionName: 'name' as const },
        { address, abi: fleetCommanderAbi, functionName: 'symbol' as const },
        { address, abi: fleetCommanderAbi, functionName: 'decimals' as const },
        { address, abi: fleetCommanderAbi, functionName: 'asset' as const },
      ])
      const fleetMeta = await client.multicall({
        contracts: fleetCalls,
        allowFailure: false,
      })

      // Unique assets — read symbol+decimals once each.
      const fleetEntries = fleetAddresses.map((address, i) => {
        const base = i * 4
        return {
          address,
          name: fleetMeta[base] as string,
          symbol: fleetMeta[base + 1] as string,
          decimals: fleetMeta[base + 2] as number,
          assetAddress: fleetMeta[base + 3] as Address,
        }
      })
      const uniqueAssets = Array.from(
        new Set(fleetEntries.map((e) => e.assetAddress.toLowerCase())),
      ).map(
        (lower) =>
          // pick checksummed back from one of the entries
          fleetEntries.find((e) => e.assetAddress.toLowerCase() === lower)!.assetAddress,
      )

      // Stage 2: per-asset symbol + decimals.
      const assetCalls = uniqueAssets.flatMap((address) => [
        { address, abi: erc20Abi, functionName: 'symbol' as const },
        { address, abi: erc20Abi, functionName: 'decimals' as const },
      ])
      const assetMeta = uniqueAssets.length
        ? await client.multicall({ contracts: assetCalls, allowFailure: false })
        : []

      const assetMetaByLower = new Map<string, { symbol: string; decimals: number }>()
      uniqueAssets.forEach((address, i) => {
        assetMetaByLower.set(address.toLowerCase(), {
          symbol: assetMeta[i * 2] as string,
          decimals: assetMeta[i * 2 + 1] as number,
        })
      })

      return fleetEntries.map((e): ActiveFleet => {
        const am = assetMetaByLower.get(e.assetAddress.toLowerCase())!
        return {
          address: e.address,
          name: e.name,
          symbol: e.symbol,
          decimals: e.decimals,
          asset: {
            address: e.assetAddress,
            symbol: am.symbol,
            decimals: am.decimals,
          },
          feed: lookupFeedForAsset(chainId, e.assetAddress),
        }
      })
    },
  })
}
