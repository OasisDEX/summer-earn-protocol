import { runSettled, type StepExecutor } from '@halaprix/domino'

import { CHAIN_RPC_URLS } from '@/config/chains'
import { type Environment, HARBOR_COMMAND_ADDRESSES } from '@/config/environments'
import { createExecutorForChain, DEFAULT_RUN_OPTIONS } from '@/lib/domino/executor'
import {
  buildActiveFleetsTask,
  buildArkOverviewTask,
  buildFleetArksIndexTask,
  buildFleetSummaryTask,
  toArkOverview,
  toFleetSummary,
  type FleetSummaryReads,
} from '@/lib/domino/tasks/arks-overview-task'
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
  executor?: StepExecutor,
): Promise<FleetSummary[]> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  const harbor = HARBOR_COMMAND_ADDRESSES[environment][Number(chainId)]
  if (!rpcUrls || !harbor) {
    throw new ArksOverviewError('Unsupported chain or environment', 400)
  }
  const exec = executor ?? createExecutorForChain(chainId)

  const [harborResult] = await runSettled(
    exec,
    [buildActiveFleetsTask(harbor as `0x${string}`)],
    DEFAULT_RUN_OPTIONS,
  )
  const activeFleets =
    harborResult.status === 'fulfilled' && harborResult.value.fleets !== undefined
      ? (harborResult.value.fleets as `0x${string}`[])
      : undefined
  if (activeFleets === undefined) {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }

  const allFleets = [...activeFleets]
  if (chainId === '8453') {
    allFleets.push('0x29f13a877F3d1A14AC0B15B07536D4423b35E198' as `0x${string}`)
  }

  const settled = await runSettled(
    exec,
    allFleets.map((fleet) => buildFleetSummaryTask(fleet)),
    DEFAULT_RUN_OPTIONS,
  )
  return settled.map((result, i) => {
    if (result.status === 'rejected') {
      throw new ArksOverviewError('Failed to read fleet contract', 502)
    }
    return toFleetSummary(allFleets[i], result.value as FleetSummaryReads)
  })
}

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
  executor?: StepExecutor,
): Promise<ArkOverview[]> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) throw new ArksOverviewError('Unsupported chainId', 400)
  const exec = executor ?? createExecutorForChain(chainId)

  const [indexResult] = await runSettled(
    exec,
    [buildFleetArksIndexTask(fleetAddress)],
    DEFAULT_RUN_OPTIONS,
  )
  if (indexResult.status === 'rejected') {
    throw new ArksOverviewError('Failed to read fleet arks', 502)
  }
  const activeArks = indexResult.value.activeArks as `0x${string}`[] | undefined
  const bufferArkAddress = indexResult.value.bufferArk as `0x${string}` | undefined
  const assetAddress = (indexResult.value.asset as `0x${string}` | undefined) ?? null
  if (activeArks === undefined || bufferArkAddress === undefined) {
    throw new ArksOverviewError('Failed to read fleet arks', 502)
  }

  const allArks = [...activeArks, bufferArkAddress]
  if (allArks.length === 0) return []

  const settled = await runSettled(
    exec,
    allArks.map((ark) => buildArkOverviewTask({ ark, fleetAsset: assetAddress })),
    DEFAULT_RUN_OPTIONS,
  )
  return settled.map((result, i) => {
    if (result.status === 'rejected') {
      throw new ArksOverviewError('Failed to read ark data', 502)
    }
    return toArkOverview(allArks[i], i === allArks.length - 1, result.value)
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
