import { NextResponse } from 'next/server'
import { createPublicClient } from 'viem'

import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { harborCommandAbi } from '@/abis/HarborCommand'
import { tipJarAbi } from '@/abis/TipJar'
import { getHarborCommand, getTipJarInstances } from '@/app/tipjar/lib/tipJarConfig'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import type { ChainId } from '@/types'

// Pending amounts drift as fees accrue, so keep the cache short. A successful
// shake refetches with `?refresh=true` to bypass it entirely.
const TTL_MS = 20 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

const INSTANCE_READS = 3 // getAllTipStreams, getTotalAllocation, paused
const FLEET_META_READS = 3 // name, symbol, asset

// Canonical Multicall3 deployment, identical across all supported chains. Some
// viem chain entities (e.g. HyperEVM) don't ship a multicall3 address, so we set
// it explicitly to keep client.multicall working everywhere.
const MULTICALL3_ADDRESS = '0xcA11bde05977b3631167028862bE2a173976CA11' as const

type RawStream = { recipient: `0x${string}`; allocation: bigint; lockedUntilEpoch: bigint }

export async function GET(request: Request) {
  try {
    const url = new URL(request.url)
    const chainId = (url.searchParams.get('chainId') || '1') as ChainId
    const refresh = url.searchParams.get('refresh') === 'true'

    const now = Date.now()
    if (!refresh) {
      const cached = cache.get(chainId)
      if (cached && cached.expiry > now) {
        return NextResponse.json(cached.data)
      }
    }

    const rpcUrls = CHAIN_RPC_URLS[chainId]
    const instances = getTipJarInstances(chainId)
    if (!rpcUrls || instances.length === 0) {
      return NextResponse.json(
        { error: 'Unsupported chain or no TipJar deployed' },
        { status: 400 },
      )
    }

    const baseChain = VIEM_CHAIN_ENTITIES[chainId]
    const client = createPublicClient({
      transport: createRpcTransport(rpcUrls),
      chain: {
        ...baseChain,
        contracts: {
          ...baseChain.contracts,
          multicall3: { address: MULTICALL3_ADDRESS },
        },
      },
    })

    // Active fleet commanders (shared by every TipJar instance on this chain).
    const harbor = getHarborCommand(chainId)
    let activeFleets: `0x${string}`[] = []
    if (harbor) {
      try {
        // @ts-ignore - harborCommandAbi / viem type mismatch (authorizationList)
        activeFleets = (await client.readContract({
          address: harbor,
          abi: harborCommandAbi,
          functionName: 'getActiveFleetCommanders',
        })) as `0x${string}`[]
      } catch {
        activeFleets = []
      }
    }

    // --- Per-instance tip stream config ---
    const instanceContracts = instances.flatMap((inst) => [
      { address: inst.address, abi: tipJarAbi, functionName: 'getAllTipStreams' as const },
      { address: inst.address, abi: tipJarAbi, functionName: 'getTotalAllocation' as const },
      { address: inst.address, abi: tipJarAbi, functionName: 'paused' as const },
    ])
    // @ts-expect-error - viem multicall types are overly strict
    const instanceResults = await client.multicall({
      contracts: instanceContracts,
      allowFailure: true,
    })

    // --- Fleet metadata (name, symbol, asset) ---
    const fleetMetaContracts = activeFleets.flatMap((f) => [
      { address: f, abi: fleetCommanderAbi, functionName: 'name' as const },
      { address: f, abi: fleetCommanderAbi, functionName: 'symbol' as const },
      { address: f, abi: fleetCommanderAbi, functionName: 'asset' as const },
    ])
    const fleetMetaResults = activeFleets.length
      ? // @ts-expect-error - viem multicall types are overly strict
        await client.multicall({ contracts: fleetMetaContracts, allowFailure: true })
      : []

    const fleetMeta = activeFleets.map((address, i) => {
      const nameRes = fleetMetaResults[i * FLEET_META_READS]
      const symbolRes = fleetMetaResults[i * FLEET_META_READS + 1]
      const assetRes = fleetMetaResults[i * FLEET_META_READS + 2]
      return {
        address,
        name: nameRes?.status === 'success' ? (nameRes.result as string) : 'Unknown fleet',
        symbol: symbolRes?.status === 'success' ? (symbolRes.result as string) : '',
        asset: assetRes?.status === 'success' ? (assetRes.result as `0x${string}`) : null,
      }
    })

    // --- Asset decimals + symbol (only for fleets with a readable asset) ---
    const assetFleetIndex: number[] = []
    const assetContracts: { address: `0x${string}`; abi: typeof erc20Abi; functionName: string }[] =
      []
    fleetMeta.forEach((fm, i) => {
      if (fm.asset) {
        assetContracts.push({ address: fm.asset, abi: erc20Abi, functionName: 'decimals' })
        assetContracts.push({ address: fm.asset, abi: erc20Abi, functionName: 'symbol' })
        assetFleetIndex.push(i)
      }
    })
    const assetResults = assetContracts.length
      ? // @ts-expect-error - viem multicall types are overly strict
        await client.multicall({ contracts: assetContracts, allowFailure: true })
      : []

    const assetInfo: Record<number, { decimals: number; symbol: string }> = {}
    assetFleetIndex.forEach((fleetIdx, k) => {
      const decimalsRes = assetResults[k * 2]
      const symbolRes = assetResults[k * 2 + 1]
      assetInfo[fleetIdx] = {
        decimals: decimalsRes?.status === 'success' ? Number(decimalsRes.result) : 18,
        symbol: symbolRes?.status === 'success' ? String(symbolRes.result) : '',
      }
    })

    // --- Per (instance, fleet) pending shares -> assets ---
    const balanceContracts = instances.flatMap((inst) =>
      fleetMeta.map((fm) => ({
        address: fm.address,
        abi: fleetCommanderAbi,
        functionName: 'balanceOf' as const,
        args: [inst.address] as const,
      })),
    )
    const balanceResults = balanceContracts.length
      ? // @ts-expect-error - viem multicall types are overly strict
        await client.multicall({ contracts: balanceContracts, allowFailure: true })
      : []

    const convertContracts = balanceResults.map((r, idx) => {
      const fleetIdx = idx % fleetMeta.length
      const shares = r.status === 'success' ? (r.result as bigint) : 0n
      return {
        address: fleetMeta[fleetIdx].address,
        abi: fleetCommanderAbi,
        functionName: 'convertToAssets' as const,
        args: [shares] as const,
      }
    })
    const convertResults = convertContracts.length
      ? // @ts-expect-error - viem multicall types are overly strict
        await client.multicall({ contracts: convertContracts, allowFailure: true })
      : []

    // --- Assemble ---
    const fleetCount = fleetMeta.length
    const payloadInstances = instances.map((inst, ii) => {
      const base = ii * INSTANCE_READS
      const streamsRes = instanceResults[base]
      const totalRes = instanceResults[base + 1]
      const pausedRes = instanceResults[base + 2]

      const rawStreams =
        streamsRes?.status === 'success' ? (streamsRes.result as readonly RawStream[]) : []

      const fleets = fleetMeta.map((fm, fi) => {
        const linear = ii * fleetCount + fi
        const sharesRes = balanceResults[linear]
        const assetsRes = convertResults[linear]
        const info = assetInfo[fi] ?? { decimals: 18, symbol: '' }
        return {
          address: fm.address,
          name: fm.name,
          assetSymbol: info.symbol || fm.symbol,
          assetDecimals: info.decimals,
          pendingShares: (sharesRes?.status === 'success'
            ? (sharesRes.result as bigint)
            : 0n
          ).toString(),
          pendingAssets: (assetsRes?.status === 'success'
            ? (assetsRes.result as bigint)
            : 0n
          ).toString(),
        }
      })

      return {
        label: inst.label,
        address: inst.address,
        paused: pausedRes?.status === 'success' ? Boolean(pausedRes.result) : false,
        totalAllocation: (totalRes?.status === 'success'
          ? (totalRes.result as bigint)
          : 0n
        ).toString(),
        streams: rawStreams.map((s) => ({
          recipient: s.recipient,
          allocation: s.allocation.toString(),
          lockedUntilEpoch: s.lockedUntilEpoch.toString(),
        })),
        fleets,
      }
    })

    const payload = { chainId, instances: payloadInstances }
    cache.set(chainId, { data: payload, expiry: now + TTL_MS })
    return NextResponse.json(payload, { status: 200 })
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
