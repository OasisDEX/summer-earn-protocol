import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { harborCommandAbi } from '@/abis/HarborCommand'
import { CHAIN_RPC_URLS } from '@/config/chains'
import { HARBOR_COMMAND_ADDRESSES, type Environment } from '@/config/environments'
import { NextResponse } from 'next/server'
import { createPublicClient, http } from 'viem'

const TTL_MS = 10 * 60 * 1000 // 10 minutes
const cache = new Map<string, { data: unknown; expiry: number }>()

function getCacheKey(params: URLSearchParams): string {
  const env = params.get('environment') || 'production'
  const chainId = params.get('chainId') || '1'
  return `${env}:${chainId}`
}

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
    console.log('chainId', chainId)
    const rpcUrl = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
    const harbor = HARBOR_COMMAND_ADDRESSES[environment][Number(chainId)]
    if (!rpcUrl || !harbor) {
      return NextResponse.json({ error: 'Unsupported chain or environment' }, { status: 400 })
    }
    console.log('rpcUrl', rpcUrl)
    const client = createPublicClient({ transport: http(rpcUrl) })
    const activeFleets = (await client.readContract({
      address: harbor as `0x${string}`,
      abi: harborCommandAbi,
      functionName: 'getActiveFleetCommanders',
    })) as `0x${string}`[]

    console.log('activeFleets', activeFleets)
    const allFleets = [...activeFleets]
    // Preserve existing Base chain special-case if needed
    if (chainId === '8453') {
      allFleets.push('0x29f13a877F3d1A14AC0B15B07536D4423b35E198' as `0x${string}`)
    }

    const results = await Promise.all(
      allFleets.map(async (fleetAddress) => {
        const [name, symbol, assetAddress, totalAssets, withdrawableTotalAssets] =
          await Promise.all([
            client.readContract({
              address: fleetAddress,
              abi: fleetCommanderAbi,
              functionName: 'name',
            }),
            client.readContract({
              address: fleetAddress,
              abi: fleetCommanderAbi,
              functionName: 'symbol',
            }),
            client.readContract({
              address: fleetAddress,
              abi: fleetCommanderAbi,
              functionName: 'asset',
            }),
            client.readContract({
              address: fleetAddress,
              abi: fleetCommanderAbi,
              functionName: 'totalAssets',
            }),
            client.readContract({
              address: fleetAddress,
              abi: fleetCommanderAbi,
              functionName: 'withdrawableTotalAssets',
            }),
          ])

        const [assetDecimals, assetSymbol] = await Promise.all([
          client.readContract({
            address: assetAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'decimals',
          }),
          client.readContract({
            address: assetAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'symbol',
          }),
        ])

        return {
          address: fleetAddress,
          name,
          symbol,
          asset: assetAddress,
          totalAssets: (totalAssets as bigint).toString(),
          withdrawableTotalAssets: (withdrawableTotalAssets as bigint).toString(),
          depositCap: '0',
          assetDecimals: Number(assetDecimals),
          assetSymbol: String(assetSymbol),
          fleetDecimals: Number(assetDecimals),
        }
      }),
    )

    const payload = { chainId, environment, fleets: results }
    cache.set(key, { data: payload, expiry: now + TTL_MS })

    return NextResponse.json(payload, { status: 200 })
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
