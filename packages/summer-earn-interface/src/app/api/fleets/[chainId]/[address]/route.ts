import { NextResponse } from 'next/server'
import { createPublicClient, getAddress } from 'viem'

import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'

const TTL_MS = 10 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

type FleetUserInfo = {
  balance: string
  underlyingBalance: string
  allowance: string
}

export async function GET(
  request: Request,
  { params }: { params: Promise<{ chainId: string; address: string }> },
) {
  const { chainId, address } = await params
  const url = new URL(request.url)
  const user = url.searchParams.get('user')
  const key = `${chainId}:${address}:${user ?? ''}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const client = createPublicClient({
    transport: createRpcTransport(rpcUrls),
    chain: VIEM_CHAIN_ENTITIES[chainId],
  })
  const fleetAddr = getAddress(address)

  // Multicall 1: fleet contract reads
  const fleetContracts = [
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'name' as const },
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'symbol' as const },
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'asset' as const },
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'totalAssets' as const },
    {
      address: fleetAddr,
      abi: fleetCommanderAbi,
      functionName: 'withdrawableTotalAssets' as const,
    },
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'decimals' as const },
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'getConfig' as const },
  ]
  // @ts-ignore - viem multicall types are overly strict
  const fleetResults = await client.multicall({
    contracts: fleetContracts,
    allowFailure: true,
  })

  const [nameRes, symbolRes, assetRes, totalRes, withdrawableRes, decimalsRes, configRes] =
    fleetResults
  if (
    nameRes.status === 'failure' ||
    symbolRes.status === 'failure' ||
    assetRes.status === 'failure' ||
    totalRes.status === 'failure' ||
    withdrawableRes.status === 'failure' ||
    decimalsRes.status === 'failure' ||
    configRes.status === 'failure'
  ) {
    return NextResponse.json({ error: 'Failed to read fleet contract' }, { status: 502 })
  }

  const assetAddress = assetRes.result as `0x${string}`
  const totalAssets = totalRes.result as bigint
  const withdrawableTotalAssets = withdrawableRes.result as bigint
  const fleetDecimals = decimalsRes.result as number
  const config = configRes.result

  // Multicall 2: asset contract + optional user reads
  const assetAndUserCalls = [
    { address: assetAddress, abi: erc20Abi, functionName: 'decimals' as const },
    { address: assetAddress, abi: erc20Abi, functionName: 'symbol' as const },
    ...(user
      ? [
          {
            address: fleetAddr,
            abi: fleetCommanderAbi,
            functionName: 'balanceOf' as const,
            args: [user as `0x${string}`],
          },
          {
            address: assetAddress,
            abi: erc20Abi,
            functionName: 'balanceOf' as const,
            args: [user as `0x${string}`],
          },
          {
            address: assetAddress,
            abi: erc20Abi,
            functionName: 'allowance' as const,
            args: [user as `0x${string}`, fleetAddr],
          },
        ]
      : []),
  ]

  // @ts-ignore - viem multicall types are overly strict with mixed contracts
  const assetUserResults = await client.multicall({
    contracts: assetAndUserCalls,
    allowFailure: true,
  })

  const assetDecimalsRes = assetUserResults[0]
  const assetSymbolRes = assetUserResults[1]
  if (assetDecimalsRes.status === 'failure' || assetSymbolRes.status === 'failure') {
    return NextResponse.json({ error: 'Failed to read asset contract' }, { status: 502 })
  }

  const assetDecimals = Number(assetDecimalsRes.result)
  const assetSymbol = String(assetSymbolRes.result)

  let userInfo: FleetUserInfo | null = null
  if (user && assetUserResults.length >= 5) {
    const [balanceRes, underlyingRes, allowanceRes] = assetUserResults.slice(2)
    if (
      balanceRes.status === 'failure' ||
      underlyingRes.status === 'failure' ||
      allowanceRes.status === 'failure'
    ) {
      return NextResponse.json({ error: 'Failed to read user info' }, { status: 502 })
    }
    userInfo = {
      balance: (balanceRes.result as bigint).toString(),
      underlyingBalance: (underlyingRes.result as bigint).toString(),
      allowance: (allowanceRes.result as bigint).toString(),
    }
  }

  // Extract depositCap from config (FleetConfig struct: [bufferArk, minimumBufferBalance, depositCap, maxRebalanceOperations, stakingRewardsManager])
  const configData = config as unknown as {
    bufferArk: `0x${string}`
    minimumBufferBalance: bigint
    depositCap: bigint
    maxRebalanceOperations: bigint
    stakingRewardsManager: `0x${string}`
  }

  const payload = {
    address,
    name: nameRes.result,
    symbol: symbolRes.result,
    asset: assetAddress,
    totalAssets: totalAssets.toString(),
    withdrawableTotalAssets: withdrawableTotalAssets.toString(),
    depositCap: configData.depositCap.toString(),
    minimumBufferBalance: configData.minimumBufferBalance.toString(),
    maxRebalanceOperations: configData.maxRebalanceOperations.toString(),
    assetDecimals: Number(assetDecimals),
    assetSymbol: String(assetSymbol),
    fleetDecimals: Number(fleetDecimals),
    userInfo,
  }

  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
