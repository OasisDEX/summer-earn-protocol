import { NextResponse } from 'next/server'
import { createPublicClient } from 'viem'

import { arkAbi } from '@/abis/Ark'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { CHAIN_RPC_URLS, createRpcTransport } from '@/config/chains'

const TTL_MS = 10 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(
  _request: Request,
  { params }: { params: { chainId: string; address: string } },
) {
  const { chainId, address } = params
  const key = `arks:${chainId}:${address}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const client = createPublicClient({ transport: createRpcTransport(rpcUrls) })

  const [activeArks, bufferArkAddress] = await Promise.all([
    // @ts-ignore
    client.readContract({
      address: address as `0x${string}`,
      abi: fleetCommanderAbi,
      functionName: 'getActiveArks',
    }) as Promise<`0x${string}`[]>,
    // @ts-ignore
    client.readContract({
      address: address as `0x${string}`,
      abi: fleetCommanderAbi,
      functionName: 'bufferArk',
    }) as Promise<`0x${string}`>,
  ])

  const allArks = [...activeArks, bufferArkAddress]
  if (allArks.length === 0) return NextResponse.json([])

  const results = await Promise.all(
    allArks.map(async (arkAddress) => {
      const [
        totalAssets,
        withdrawableTotalAssets,
        name,
        depositCap,
        maxDepositPercentageOfTVL,
        maxRebalanceInflow,
        maxRebalanceOutflow,
      ] = await Promise.all([
        // @ts-ignore
        client.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'totalAssets',
        }),
        // @ts-ignore
        client.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'withdrawableTotalAssets',
        }),
        // @ts-ignore
        client.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'name',
        }),
        // @ts-ignore
        client.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'depositCap',
        }),
        // @ts-ignore
        client.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'maxDepositPercentageOfTVL',
        }),
        // @ts-ignore
        client.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'maxRebalanceInflow',
        }),
        // @ts-ignore
        client.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'maxRebalanceOutflow',
        }),
      ])
      return {
        address: arkAddress,
        totalAssets: (totalAssets as bigint).toString(),
        withdrawableTotalAssets: (withdrawableTotalAssets as bigint).toString(),
        name: String(name),
        depositCap: (depositCap as bigint).toString(),
        maxDepositPercentageOfTVL: (maxDepositPercentageOfTVL as bigint).toString(),
        maxRebalanceInflow: (maxRebalanceInflow as bigint).toString(),
        maxRebalanceOutflow: (maxRebalanceOutflow as bigint).toString(),
      }
    }),
  )

  const payload = results.map((ark, i) => ({ ...ark, isBufferArk: i === allArks.length - 1 }))
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
