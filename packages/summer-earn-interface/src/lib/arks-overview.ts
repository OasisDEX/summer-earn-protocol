import { createPublicClient } from 'viem'

import { arkAbi } from '@/abis/Ark'
import { arkWithWithdrawalRequestAbi } from '@/abis/ArkWithWithdrawalRequest'
import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { harborCommandAbi } from '@/abis/HarborCommand'
import { wisdomTreeArkAbi } from '@/abis/WisdomTreeArk'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { type Environment, HARBOR_COMMAND_ADDRESSES } from '@/config/environments'
import type { ChainId } from '@/types'

const POOL_ADDRESS_RE = /^0x[a-fA-F0-9]{40}$/

export type ArkStatus = 'active' | 'ready-to-remove' | 'stuck-needs-sweep'

export interface ArkDetails {
  protocol?: string
  pool?: `0x${string}`
  chainId?: number
}

export function getArkStatus(ark: {
  isBufferArk: boolean
  depositCap: bigint
  totalAssets: bigint
}): ArkStatus {
  if (ark.isBufferArk) return 'active'
  if (ark.depositCap === 0n) {
    return ark.totalAssets === 0n ? 'ready-to-remove' : 'stuck-needs-sweep'
  }
  return 'active'
}

export function parseArkDetails(detailsJson: string | undefined): ArkDetails | null {
  if (!detailsJson) return null
  try {
    const parsed = JSON.parse(detailsJson) as Record<string, unknown>
    const pool =
      typeof parsed.pool === 'string' && POOL_ADDRESS_RE.test(parsed.pool)
        ? (parsed.pool as `0x${string}`)
        : undefined
    const protocol = typeof parsed.protocol === 'string' ? parsed.protocol : undefined
    const chainId = typeof parsed.chainId === 'number' ? parsed.chainId : undefined
    return { protocol, pool, chainId }
  } catch {
    return null
  }
}

export class ArksOverviewError extends Error {
  status: number
  constructor(message: string, status = 502) {
    super(message)
    this.status = status
  }
}

const FLEET_READS_PER_CONTRACT = 6

export interface FleetSummary {
  address: `0x${string}`
  name: string
  symbol: string
  asset: `0x${string}`
  totalAssets: string
  withdrawableTotalAssets: string
  depositCap: string
  minimumBufferBalance: string
  maxRebalanceOperations: string
  assetDecimals: number
  assetSymbol: string
  fleetDecimals: number
}

export async function getFleetsForChain(
  chainId: string,
  environment: Environment,
): Promise<FleetSummary[]> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  const harbor = HARBOR_COMMAND_ADDRESSES[environment][Number(chainId)]
  if (!rpcUrls || !harbor) {
    throw new ArksOverviewError('Unsupported chain or environment', 400)
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
  const fleetResults = await client.multicall({ contracts: fleetContracts, allowFailure: true })

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
    const [nameRes, symbolRes, assetRes, totalRes, withdrawableRes, configRes] = fleetResults.slice(
      base,
      base + FLEET_READS_PER_CONTRACT,
    )

    if (
      nameRes.status === 'failure' ||
      symbolRes.status === 'failure' ||
      assetRes.status === 'failure' ||
      totalRes.status === 'failure' ||
      withdrawableRes.status === 'failure' ||
      configRes.status === 'failure'
    ) {
      throw new ArksOverviewError('Failed to read fleet contract', 502)
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

  const assetContracts = assetAddresses.flatMap((assetAddress) => [
    { address: assetAddress, abi: erc20Abi, functionName: 'decimals' as const },
    { address: assetAddress, abi: erc20Abi, functionName: 'symbol' as const },
  ])

  // @ts-expect-error - viem multicall types are overly strict
  const assetResults = await client.multicall({ contracts: assetContracts, allowFailure: true })

  if (assetResults.some((r) => r.status === 'failure')) {
    throw new ArksOverviewError('Failed to read asset contract', 502)
  }

  return fleetData.map((fd, i) => {
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
}

const CALLS_PER_ARK_BASE = 7

export interface ArkOverview {
  address: `0x${string}`
  totalAssets: string
  withdrawableTotalAssets: string
  name: string
  depositCap: string
  maxDepositPercentageOfTVL: string
  maxRebalanceInflow: string
  maxRebalanceOutflow: string
  isBufferArk: boolean
  status: ArkStatus
  details: ArkDetails | null
  poolBalance: string | null
  withdrawalRequestId?: string
  assetsInWithdrawalQueue?: string
  isWithdrawalClaimRequired?: boolean
  assetBalance?: string
  needsSweep: boolean
  pendingDepositAssets?: string
  sharesToAssets1e18?: string
}

export async function getArksForFleet(
  chainId: string,
  fleetAddress: `0x${string}`,
): Promise<ArkOverview[]> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) throw new ArksOverviewError('Unsupported chainId', 400)

  const client = createPublicClient({
    transport: createRpcTransport(rpcUrls),
    chain: VIEM_CHAIN_ENTITIES[chainId as keyof typeof VIEM_CHAIN_ENTITIES],
  })

  // Multicall 1: fleet contract - getActiveArks, bufferArk, asset
  const fleetContracts = [
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'getActiveArks' as const },
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'bufferArk' as const },
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'asset' as const },
  ]
  // @ts-ignore - viem multicall types are overly strict
  const fleetResults = await client.multicall({ contracts: fleetContracts, allowFailure: true })

  const activeArksRes = fleetResults[0]
  const bufferArkRes = fleetResults[1]
  const assetRes = fleetResults[2]
  if (activeArksRes.status === 'failure' || bufferArkRes.status === 'failure') {
    throw new ArksOverviewError('Failed to read fleet arks', 502)
  }

  const activeArks = activeArksRes.result as `0x${string}`[]
  const bufferArkAddress = bufferArkRes.result as `0x${string}`
  const assetAddress = assetRes.status === 'success' ? (assetRes.result as `0x${string}`) : null
  const allArks = [...activeArks, bufferArkAddress]
  if (allArks.length === 0) return []

  const callsPerArk = CALLS_PER_ARK_BASE + 5 + (assetAddress ? 1 : 0)

  // Multicall 2: base ark reads + optional IArkWithWithdrawalRequest reads + asset balanceOf
  // (unchanged from the pre-extraction route — do not add new calls to this batch, see Step 3
  // note below for why details()/pool-balance are separate batches)
  const arkCalls = allArks.flatMap((arkAddress) => [
    { address: arkAddress, abi: arkAbi, functionName: 'totalAssets' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'withdrawableTotalAssets' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'name' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'depositCap' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'maxDepositPercentageOfTVL' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'maxRebalanceInflow' as const },
    { address: arkAddress, abi: arkAbi, functionName: 'maxRebalanceOutflow' as const },
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
    { address: arkAddress, abi: wisdomTreeArkAbi, functionName: 'pendingDepositAssets' as const },
    {
      address: arkAddress,
      abi: wisdomTreeArkAbi,
      functionName: 'sharesToAssets' as const,
      args: [1000000000000000000n] as const,
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
  const arkResults = await client.multicall({ contracts: arkCalls as any, allowFailure: true })

  for (let i = 0; i < allArks.length; i++) {
    const base = i * callsPerArk
    const hasBaseFailure = arkResults
      .slice(base, base + CALLS_PER_ARK_BASE)
      .some((r) => r.status === 'failure')
    if (hasBaseFailure) throw new ArksOverviewError('Failed to read ark data', 502)
  }

  // Multicall 3 (NEW): best-effort details() per ark — never gates on failure
  const detailsCalls = allArks.map((arkAddress) => ({
    address: arkAddress,
    abi: arkAbi,
    functionName: 'details' as const,
  }))
  // @ts-ignore - viem multicall types are overly strict
  const detailsResults = await client.multicall({ contracts: detailsCalls, allowFailure: true })
  const parsedDetails = detailsResults.map((r) =>
    parseArkDetails(r.status === 'success' ? (r.result as string) : undefined),
  )

  // Multicall 4 (NEW): best-effort pool-token balanceOf(ark), only for arks whose details().pool
  // resolved to a valid 20-byte address (see design doc table — Aave-fork/Sky/Morpho-Blue arks
  // will not have a resolvable pool here, and that's expected)
  const poolLookups: Array<{
    index: number
    arkAddress: `0x${string}`
    poolAddress: `0x${string}`
  }> = []
  allArks.forEach((arkAddress, i) => {
    const pool = parsedDetails[i]?.pool
    if (pool) poolLookups.push({ index: i, arkAddress, poolAddress: pool })
  })
  const poolBalanceResults = poolLookups.length
    ? // @ts-ignore - viem multicall types are overly strict
      await client.multicall({
        contracts: poolLookups.map(({ arkAddress, poolAddress }) => ({
          address: poolAddress,
          abi: erc20Abi,
          functionName: 'balanceOf' as const,
          args: [arkAddress] as const,
        })),
        allowFailure: true,
      })
    : []
  const poolBalanceByIndex = new Map<number, string>()
  poolLookups.forEach(({ index }, j) => {
    const res = poolBalanceResults[j]
    if (res && res.status === 'success') {
      poolBalanceByIndex.set(index, (res.result as bigint).toString())
    }
  })

  return allArks.map((arkAddress, i) => {
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
      pendingDepositAssetsRes,
      sharesToAssets1e18Res,
    ] = slice
    const assetBalanceRes = assetAddress ? slice[12] : undefined

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
    const pendingDepositAssets =
      pendingDepositAssetsRes?.status === 'success'
        ? (pendingDepositAssetsRes.result as bigint).toString()
        : undefined
    const sharesToAssets1e18 =
      sharesToAssets1e18Res?.status === 'success'
        ? (sharesToAssets1e18Res.result as bigint).toString()
        : undefined
    const hasWithdrawalQueue =
      withdrawalRequestIdRes?.status === 'success' ||
      assetsInWithdrawalQueueRes?.status === 'success' ||
      isWithdrawalClaimRequiredRes?.status === 'success'

    const isBufferArk = i === allArks.length - 1
    const depositCap = capRes.result as bigint
    const totalAssets = totalRes.result as bigint

    return {
      address: arkAddress,
      totalAssets: totalAssets.toString(),
      withdrawableTotalAssets: (withdrawableRes.result as bigint).toString(),
      name: String(nameRes.result),
      depositCap: depositCap.toString(),
      maxDepositPercentageOfTVL: (maxPctRes.result as bigint).toString(),
      maxRebalanceInflow: (inflowRes.result as bigint).toString(),
      maxRebalanceOutflow: (outflowRes.result as bigint).toString(),
      isBufferArk,
      status: getArkStatus({ isBufferArk, depositCap, totalAssets }),
      details: parsedDetails[i],
      poolBalance: poolBalanceByIndex.get(i) ?? null,
      ...(hasWithdrawalQueue && {
        withdrawalRequestId,
        assetsInWithdrawalQueue,
        isWithdrawalClaimRequired,
      }),
      assetBalance,
      needsSweep: assetBalance !== undefined && assetBalance !== '0',
      ...(pendingDepositAssets !== undefined && { pendingDepositAssets }),
      ...(sharesToAssets1e18 !== undefined && { sharesToAssets1e18 }),
    }
  })
}

export function computeBufferSharePct(bufferTotal: bigint, fleetTotal: bigint): number | null {
  if (fleetTotal === 0n) return null
  return Math.round(Number((bufferTotal * 1000000n) / fleetTotal) / 100) / 100
}

export interface FleetOverview extends FleetSummary {
  chainId: ChainId
  bufferArkAddress: `0x${string}`
  bufferArkTotalAssets: string
  bufferSharePct: number | null
  arks: ArkOverview[]
}

export interface ChainArksOverview {
  chainId: ChainId
  fleets: FleetOverview[]
  error?: string
}

export async function getAllArksOverview(environment: Environment): Promise<ChainArksOverview[]> {
  const chainIds = Object.keys(HARBOR_COMMAND_ADDRESSES[environment]) as ChainId[]

  return Promise.all(
    chainIds.map(async (chainId): Promise<ChainArksOverview> => {
      try {
        const fleets = await getFleetsForChain(chainId, environment)
        const fleetResults = await Promise.allSettled(
          fleets.map(async (fleet): Promise<FleetOverview> => {
            const arks = await getArksForFleet(chainId, fleet.address)
            const bufferArk = arks.find((a) => a.isBufferArk)
            const bufferSharePct = computeBufferSharePct(
              BigInt(bufferArk?.totalAssets ?? '0'),
              BigInt(fleet.totalAssets),
            )
            return {
              ...fleet,
              chainId,
              bufferArkAddress:
                bufferArk?.address ?? ('0x0000000000000000000000000000000000000000' as const),
              bufferArkTotalAssets: bufferArk?.totalAssets ?? '0',
              bufferSharePct,
              arks,
            }
          }),
        )

        // A single fleet's arks failing to load (e.g. an RPC hiccup) must not blank the
        // whole chain — isolate each fleet's failure and drop only that fleet, logging it
        // for visibility, while every other successfully-loaded fleet is still returned.
        const fleetOverviews: FleetOverview[] = []
        for (const [index, result] of fleetResults.entries()) {
          if (result.status === 'fulfilled') {
            fleetOverviews.push(result.value)
          } else {
            console.error(
              `getAllArksOverview: failed to load arks for fleet ${fleets[index].address} on chain ${chainId}`,
              result.reason,
            )
          }
        }

        return { chainId, fleets: fleetOverviews }
      } catch (err) {
        return { chainId, fleets: [], error: (err as Error).message }
      }
    }),
  )
}
