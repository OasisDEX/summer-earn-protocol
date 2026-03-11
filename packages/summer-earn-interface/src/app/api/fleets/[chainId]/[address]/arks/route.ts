import { NextResponse } from 'next/server'
import { createPublicClient } from 'viem'

import { arkAbi } from '@/abis/Ark'
import { arkWithWithdrawalRequestAbi } from '@/abis/ArkWithWithdrawalRequest'
import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'

const TTL_MS = 10 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()
const CALLS_PER_ARK_BASE = 7

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ chainId: string; address: string }> },
) {
  const { chainId, address } = await params
  const key = `arks:${chainId}:${address}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const client = createPublicClient({
    transport: createRpcTransport(rpcUrls),
    chain: VIEM_CHAIN_ENTITIES[chainId],
  })
  const fleetAddr = address as `0x${string}`

  // Multicall 1: fleet contract - getActiveArks, bufferArk, asset
  const fleetContracts = [
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'getActiveArks' as const },
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'bufferArk' as const },
    { address: fleetAddr, abi: fleetCommanderAbi, functionName: 'asset' as const },
  ]
  // @ts-ignore - viem multicall types are overly strict
  const fleetResults = await client.multicall({
    contracts: fleetContracts,
    allowFailure: true,
  })

  const activeArksRes = fleetResults[0]
  const bufferArkRes = fleetResults[1]
  const assetRes = fleetResults[2]
  if (activeArksRes.status === 'failure' || bufferArkRes.status === 'failure') {
    return NextResponse.json({ error: 'Failed to read fleet arks' }, { status: 502 })
  }

  const activeArks = activeArksRes.result as `0x${string}`[]
  const bufferArkAddress = bufferArkRes.result as `0x${string}`
  const assetAddress = assetRes.status === 'success' ? (assetRes.result as `0x${string}`) : null
  const allArks = [...activeArks, bufferArkAddress]
  if (allArks.length === 0) return NextResponse.json([])

  const callsPerArk = CALLS_PER_ARK_BASE + 3 + (assetAddress ? 1 : 0)

  // Multicall 2: base ark reads + optional IArkWithWithdrawalRequest reads + asset balanceOf
  const arkCalls = allArks.flatMap((arkAddress) => [
    // Base (7)
    { address: arkAddress, abi: arkAbi, functionName: 'totalAssets' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'withdrawableTotalAssets' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'name' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'depositCap' as const },
    {
      address: arkAddress,
      abi: arkAbi,
      functionName: 'maxDepositPercentageOfTVL' as const,
    },
    { address: arkAddress, abi: arkAbi, functionName: 'maxRebalanceInflow' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'maxRebalanceOutflow' as const },
    // Optional withdrawal queue (allow failure) + balanceOf
    {
      address: arkAddress,
      abi: arkWithWithdrawalRequestAbi,
      functionName: 'withdrawalRequestId' as const,
    },
    {
      address: arkAddress,
      abi: arkWithWithdrawalRequestAbi,
      functionName: 'assetsInWithdrawalQueue' as const,
    },
    {
      address: arkAddress,
      abi: arkWithWithdrawalRequestAbi,
      functionName: 'isWithdrawalClaimRequired' as const,
    },
    ...(assetAddress
      ? [
          {
            address: assetAddress,
            abi: erc20Abi,
            functionName: 'balanceOf' as const,
            args: [arkAddress] as const,
          },
        ]
      : []),
  ])

  // @ts-ignore - viem multicall types are overly strict with flatMap'd contracts
  const arkResults = await client.multicall({
    contracts: arkCalls as any,
    allowFailure: true,
  })

  for (let i = 0; i < allArks.length; i++) {
    const base = i * callsPerArk
    const baseSlice = arkResults.slice(base, base + CALLS_PER_ARK_BASE)
    const hasBaseFailure = baseSlice.some((r) => r.status === 'failure')
    if (hasBaseFailure) {
      return NextResponse.json({ error: 'Failed to read ark data' }, { status: 502 })
    }
  }

  const payload = allArks.map((arkAddress, i) => {
    const base = i * callsPerArk
    const slice = arkResults.slice(base, base + callsPerArk)
    const [
      totalRes,
      withdrawableRes,
      nameRes,
      capRes,
      maxPctRes,
      inflowRes,
      outflowRes,
      withdrawalRequestIdRes,
      assetsInWithdrawalQueueRes,
      isWithdrawalClaimRequiredRes,
    ] = slice
    const assetBalanceRes = assetAddress ? slice[10] : undefined

    const withdrawalRequestId =
      withdrawalRequestIdRes?.status === 'success'
        ? (withdrawalRequestIdRes.result as bigint).toString()
        : undefined
    const assetsInWithdrawalQueue =
      assetsInWithdrawalQueueRes?.status === 'success'
        ? (assetsInWithdrawalQueueRes.result as bigint).toString()
        : undefined
    const isWithdrawalClaimRequired =
      isWithdrawalClaimRequiredRes?.status === 'success'
        ? (isWithdrawalClaimRequiredRes.result as boolean)
        : undefined
    const assetBalance =
      assetBalanceRes?.status === 'success'
        ? (assetBalanceRes.result as bigint).toString()
        : undefined

    const hasWithdrawalQueue =
      withdrawalRequestIdRes?.status === 'success' ||
      assetsInWithdrawalQueueRes?.status === 'success' ||
      isWithdrawalClaimRequiredRes?.status === 'success'

    return {
      address: arkAddress,
      totalAssets: (totalRes.result as bigint).toString(),
      withdrawableTotalAssets: (withdrawableRes.result as bigint).toString(),
      name: String(nameRes.result),
      depositCap: (capRes.result as bigint).toString(),
      maxDepositPercentageOfTVL: (maxPctRes.result as bigint).toString(),
      maxRebalanceInflow: (inflowRes.result as bigint).toString(),
      maxRebalanceOutflow: (outflowRes.result as bigint).toString(),
      isBufferArk: i === allArks.length - 1,
      ...(hasWithdrawalQueue && {
        withdrawalRequestId,
        assetsInWithdrawalQueue,
        isWithdrawalClaimRequired,
      }),
      assetBalance,
      needsSweep: assetBalance !== undefined && assetBalance !== '0',
    }
  })

  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
