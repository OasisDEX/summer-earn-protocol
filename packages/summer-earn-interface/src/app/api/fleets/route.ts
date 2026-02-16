import { NextResponse } from 'next/server'
import { createPublicClient } from 'viem'

import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { harborCommandAbi } from '@/abis/HarborCommand'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { type Environment, HARBOR_COMMAND_ADDRESSES } from '@/config/environments'

const TTL_MS = 10 * 60 * 1000 // 10 minutes
const cache = new Map<string, { data: unknown; expiry: number }>()

function getCacheKey(params: URLSearchParams): string {
  const env = params.get('environment') || 'production'
  const chainId = params.get('chainId') || '1'
  return `${env}:${chainId}`
}

const FLEET_READS_PER_CONTRACT = 6

export async function GET(request: Request) {
  try {
    const url = new URL(request.url)
    const params = url.searchParams
    const chainId = params.get('chainId') || '1'
    const environment = (params.get('environment') || 'production') as Environment

    const key = getCacheKey(params)
    const now = Date.now()
    const cached = cache.get(key)
    if (cached && cached.expiry > now) {
      return NextResponse.json(cached.data)
    }
    const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
    const harbor = HARBOR_COMMAND_ADDRESSES[environment][Number(chainId)]
    if (!rpcUrls || !harbor) {
      return NextResponse.json({ error: 'Unsupported chain or environment' }, { status: 400 })
    }

    const client = createPublicClient({
      transport: createRpcTransport(rpcUrls),
      chain: VIEM_CHAIN_ENTITIES[chainId as keyof typeof VIEM_CHAIN_ENTITIES],
    })

    // @ts-ignore - harborCommandAbi / viem type mismatch (authorizationList)
    const activeFleets = (await client.readContract({
      address: harbor as `0x${string}`,
      abi: harborCommandAbi,
      functionName: 'getActiveFleetCommanders',
    })) as `0x${string}`[]

    const allFleets = [...activeFleets]
    if (chainId === '8453') {
      allFleets.push('0x29f13a877F3d1A14AC0B15B07536D4423b35E198' as `0x${string}`)
    }

    // Multicall 1: fleet contract reads (6 per fleet)
    const fleetContracts = allFleets.flatMap((fleetAddress) => [
      { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'name' as const },
      { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'symbol' as const },
      { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'asset' as const },
      { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'totalAssets' as const },
      {
        address: fleetAddress,
        abi: fleetCommanderAbi,
        functionName: 'withdrawableTotalAssets' as const,
      },
      { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'getConfig' as const },
    ])

    // @ts-expect-error - viem multicall types are overly strict
    const fleetResults = await client.multicall({
      contracts: fleetContracts,
      allowFailure: true,
    })

    const assetAddresses: `0x${string}`[] = []
    const fleetData: Array<{
      address: `0x${string}`
      name: string
      symbol: string
      asset: `0x${string}`
      totalAssets: bigint
      withdrawableTotalAssets: bigint
      config: unknown
    }> = []

    for (let i = 0; i < allFleets.length; i++) {
      const base = i * FLEET_READS_PER_CONTRACT
      const [nameRes, symbolRes, assetRes, totalRes, withdrawableRes, configRes] =
        fleetResults.slice(base, base + FLEET_READS_PER_CONTRACT)

      if (
        nameRes.status === 'failure' ||
        symbolRes.status === 'failure' ||
        assetRes.status === 'failure' ||
        totalRes.status === 'failure' ||
        withdrawableRes.status === 'failure' ||
        configRes.status === 'failure'
      ) {
        return NextResponse.json({ error: 'Failed to read fleet contract' }, { status: 502 })
      }

      const assetAddress = assetRes.result as `0x${string}`
      assetAddresses.push(assetAddress)
      fleetData.push({
        address: allFleets[i],
        name: nameRes.result as string,
        symbol: symbolRes.result as string,
        asset: assetAddress,
        totalAssets: totalRes.result as bigint,
        withdrawableTotalAssets: withdrawableRes.result as bigint,
        config: configRes.result,
      })
    }

    // Multicall 2: asset contract reads (2 per fleet)
    const assetContracts = assetAddresses.flatMap((assetAddress) => [
      { address: assetAddress, abi: erc20Abi, functionName: 'decimals' as const },
      { address: assetAddress, abi: erc20Abi, functionName: 'symbol' as const },
    ])

    // @ts-expect-error - viem multicall types are overly strict
    const assetResults = await client.multicall({
      contracts: assetContracts,
      allowFailure: true,
    })

    const hasAssetFailure = assetResults.some((r) => r.status === 'failure')
    if (hasAssetFailure) {
      return NextResponse.json({ error: 'Failed to read asset contract' }, { status: 502 })
    }

    const results = fleetData.map((fd, i) => {
      const decimalsRes = assetResults[i * 2]
      const symbolRes = assetResults[i * 2 + 1]
      const assetDecimals = Number(decimalsRes.result)
      const assetSymbol = String(symbolRes.result)

      const configData = fd.config as {
        bufferArk: `0x${string}`
        minimumBufferBalance: bigint
        depositCap: bigint
        maxRebalanceOperations: bigint
        stakingRewardsManager: `0x${string}`
      }

      return {
        address: fd.address,
        name: fd.name,
        symbol: fd.symbol,
        asset: fd.asset,
        totalAssets: fd.totalAssets.toString(),
        withdrawableTotalAssets: fd.withdrawableTotalAssets.toString(),
        depositCap: configData.depositCap.toString(),
        minimumBufferBalance: configData.minimumBufferBalance.toString(),
        maxRebalanceOperations: configData.maxRebalanceOperations.toString(),
        assetDecimals,
        assetSymbol,
        fleetDecimals: assetDecimals,
      }
    })

    const payload = { chainId, environment, fleets: results }
    cache.set(key, { data: payload, expiry: now + TTL_MS })

    return NextResponse.json(payload, { status: 200 })
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
