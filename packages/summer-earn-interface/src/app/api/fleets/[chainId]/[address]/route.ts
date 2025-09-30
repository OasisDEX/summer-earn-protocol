import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { CHAIN_RPC_URLS } from '@/config/chains'
import { NextResponse } from 'next/server'
import { createPublicClient, http } from 'viem'

const TTL_MS = 10 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(
  request: Request,
  { params }: { params: { chainId: string; address: string } },
) {
  const { chainId, address } = params
  const url = new URL(request.url)
  const user = url.searchParams.get('user')
  const key = `${chainId}:${address}:${user ?? ''}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const rpcUrl = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrl) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const client = createPublicClient({ transport: http(rpcUrl) })

  const [name, symbol, assetAddress, totalAssets, withdrawableTotalAssets, fleetDecimals] =
    await Promise.all([
      client.readContract({
        address: address as `0x${string}`,
        abi: fleetCommanderAbi,
        functionName: 'name',
        authorizationList: [],
      }),
      client.readContract({
        address: address as `0x${string}`,
        abi: fleetCommanderAbi,
        functionName: 'symbol',
        authorizationList: [],
      }),
      client.readContract({
        address: address as `0x${string}`,
        abi: fleetCommanderAbi,
        functionName: 'asset',
        authorizationList: [],
      }),
      client.readContract({
        address: address as `0x${string}`,
        abi: fleetCommanderAbi,
        functionName: 'totalAssets',
        authorizationList: [],
      }),
      client.readContract({
        address: address as `0x${string}`,
        abi: fleetCommanderAbi,
        functionName: 'withdrawableTotalAssets',
        authorizationList: [],
      }),
      client.readContract({
        address: address as `0x${string}`,
        abi: fleetCommanderAbi,
        functionName: 'decimals',
        authorizationList: [],
      }),
    ])
  const [assetDecimals, assetSymbol] = await Promise.all([
    client.readContract({
      address: assetAddress as `0x${string}`,
      abi: erc20Abi,
      functionName: 'decimals',
      authorizationList: [],
    }),
    client.readContract({
      address: assetAddress as `0x${string}`,
      abi: erc20Abi,
      functionName: 'symbol',
      authorizationList: [],
    }),
  ])

  let userInfo: any = null
  if (user) {
    const [balance, underlyingBalance, allowance] = await Promise.all([
      client.readContract({
        address: address as `0x${string}`,
        abi: fleetCommanderAbi,
        functionName: 'balanceOf',
        args: [user as `0x${string}`],
        authorizationList: [],
      }),
      client.readContract({
        address: assetAddress as `0x${string}`,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [user as `0x${string}`],
        authorizationList: [],
      }),
      client.readContract({
        address: assetAddress as `0x${string}`,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [user as `0x${string}`, address as `0x${string}`],
        authorizationList: [],
      }),
    ])
    userInfo = {
      balance: (balance as bigint).toString(),
      underlyingBalance: (underlyingBalance as bigint).toString(),
      allowance: (allowance as bigint).toString(),
    }
  }

  const payload = {
    address,
    name,
    symbol,
    asset: assetAddress,
    totalAssets: (totalAssets as bigint).toString(),
    withdrawableTotalAssets: (withdrawableTotalAssets as bigint).toString(),
    depositCap: '0',
    assetDecimals: Number(assetDecimals),
    assetSymbol: String(assetSymbol),
    fleetDecimals: Number(fleetDecimals),
    userInfo,
  }

  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
