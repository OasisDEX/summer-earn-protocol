import { defineTask, type MultistepTask } from '@halaprix/domino'

import {
  type ArkDetails,
  type ArkOverview,
  ArksOverviewError,
  type FleetSummary,
  getArkStatus,
  parseArkDetails,
} from '@/lib/arks-overview'

type Address = `0x${string}`

const harborCommandAbiHuman = [
  'function getActiveFleetCommanders() view returns (address[])',
] as const

const fleetCommanderAbiHuman = [
  'function getActiveArks() view returns (address[])',
  'function bufferArk() view returns (address)',
  'function asset() view returns (address)',
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function totalAssets() view returns (uint256)',
  'function withdrawableTotalAssets() view returns (uint256)',
  'function getConfig() view returns ((address bufferArk, uint256 minimumBufferBalance, uint256 depositCap, uint256 maxRebalanceOperations, address stakingRewardsManager))',
] as const

const arkAbiHuman = [
  'function totalAssets() view returns (uint256)',
  'function withdrawableTotalAssets() view returns (uint256)',
  'function name() view returns (string)',
  'function depositCap() view returns (uint256)',
  'function maxDepositPercentageOfTVL() view returns (uint256)',
  'function maxRebalanceInflow() view returns (uint256)',
  'function maxRebalanceOutflow() view returns (uint256)',
  'function details() view returns (string)',
] as const

const arkWithWithdrawalRequestAbiHuman = [
  'function withdrawalRequestId() view returns (uint256)',
  'function assetsInWithdrawalQueue() view returns (uint256)',
  'function isWithdrawalClaimRequired() view returns (bool)',
] as const

const wisdomTreeArkAbiHuman = [
  'function pendingDepositAssets() view returns (uint256)',
  'function sharesToAssets(uint256) view returns (uint256)',
] as const

const erc20AbiHuman = [
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function balanceOf(address) view returns (uint256)',
] as const

export interface FleetArksIndexReads {
  activeArks: unknown
  bufferArk: unknown
  asset: unknown
}

/** Step 1 of the two-phase ark overview: discover the fleet's arks. */
export function buildFleetArksIndexTask(fleet: Address): MultistepTask<FleetArksIndexReads> {
  return defineTask((t) => ({
    activeArks: t.call({
      target: fleet,
      abi: fleetCommanderAbiHuman,
      functionName: 'getActiveArks',
      optional: true,
    }),
    bufferArk: t.call({
      target: fleet,
      abi: fleetCommanderAbiHuman,
      functionName: 'bufferArk',
      optional: true,
    }),
    asset: t.call({
      target: fleet,
      abi: fleetCommanderAbiHuman,
      functionName: 'asset',
      optional: true,
    }),
  }))
}

export interface ArkReads {
  totalAssets: bigint | undefined
  withdrawableTotalAssets: bigint | undefined
  name: string | undefined
  depositCap: bigint | undefined
  maxDepositPercentageOfTVL: bigint | undefined
  maxRebalanceInflow: bigint | undefined
  maxRebalanceOutflow: bigint | undefined
  withdrawalRequestId: bigint | undefined
  assetsInWithdrawalQueue: bigint | undefined
  isWithdrawalClaimRequired: boolean | undefined
  pendingDepositAssets: bigint | undefined
  sharesToAssets1e18: bigint | undefined
  assetBalance: bigint | undefined
  details: ArkDetails | null
  poolBalance: bigint | undefined
}

/**
 * Full per-ark read graph. Base reads + details() land in step 1; the pool
 * token balanceOf runs in step 2 against a target derived from details()
 * (skip-chained to undefined when the pool is not a resolvable address —
 * Aave-fork/Sky/Morpho-Blue arks, or a failed details() call).
 */
export function buildArkOverviewTask(params: {
  ark: Address
  fleetAsset: Address | null
}): MultistepTask<ArkReads> {
  const { ark, fleetAsset } = params
  return defineTask((t) => {
    const detailsJson = t.call({
      target: ark,
      abi: arkAbiHuman,
      functionName: 'details',
      optional: true,
    })
    const details = t.derive([detailsJson], (json) => parseArkDetails(json as string | undefined))
    const poolAddress = t.derive([details], (d) => (d as ArkDetails | null)?.pool)

    return {
      totalAssets: t.call({
        target: ark,
        abi: arkAbiHuman,
        functionName: 'totalAssets',
        optional: true,
      }),
      withdrawableTotalAssets: t.call({
        target: ark,
        abi: arkAbiHuman,
        functionName: 'withdrawableTotalAssets',
        optional: true,
      }),
      name: t.call({
        target: ark,
        abi: arkAbiHuman,
        functionName: 'name',
        optional: true,
      }),
      depositCap: t.call({
        target: ark,
        abi: arkAbiHuman,
        functionName: 'depositCap',
        optional: true,
      }),
      maxDepositPercentageOfTVL: t.call({
        target: ark,
        abi: arkAbiHuman,
        functionName: 'maxDepositPercentageOfTVL',
        optional: true,
      }),
      maxRebalanceInflow: t.call({
        target: ark,
        abi: arkAbiHuman,
        functionName: 'maxRebalanceInflow',
        optional: true,
      }),
      maxRebalanceOutflow: t.call({
        target: ark,
        abi: arkAbiHuman,
        functionName: 'maxRebalanceOutflow',
        optional: true,
      }),
      withdrawalRequestId: t.call({
        target: ark,
        abi: arkWithWithdrawalRequestAbiHuman,
        functionName: 'withdrawalRequestId',
        optional: true,
      }),
      assetsInWithdrawalQueue: t.call({
        target: ark,
        abi: arkWithWithdrawalRequestAbiHuman,
        functionName: 'assetsInWithdrawalQueue',
        optional: true,
      }),
      isWithdrawalClaimRequired: t.call({
        target: ark,
        abi: arkWithWithdrawalRequestAbiHuman,
        functionName: 'isWithdrawalClaimRequired',
        optional: true,
      }),
      pendingDepositAssets: t.call({
        target: ark,
        abi: wisdomTreeArkAbiHuman,
        functionName: 'pendingDepositAssets',
        optional: true,
      }),
      sharesToAssets1e18: t.call({
        target: ark,
        abi: wisdomTreeArkAbiHuman,
        functionName: 'sharesToAssets',
        args: [1000000000000000000n],
        optional: true,
      }),
      assetBalance: fleetAsset
        ? t.call({
            target: fleetAsset,
            abi: erc20AbiHuman,
            functionName: 'balanceOf',
            args: [ark],
            optional: true,
          })
        : undefined,
      details,
      poolBalance: t.call({
        target: poolAddress as never,
        abi: erc20AbiHuman,
        functionName: 'balanceOf',
        args: [ark],
        optional: true,
      }),
    } as unknown as ArkReads
  }) as MultistepTask<ArkReads>
}

function requireRead<T>(value: T | undefined): T {
  if (value === undefined) throw new ArksOverviewError('Failed to read ark data', 502)
  return value
}

/** Pure assembly: resolved reads -> legacy ArkOverview JSON shape. */
export function toArkOverview(ark: Address, isBufferArk: boolean, reads: ArkReads): ArkOverview {
  const totalAssets = requireRead(reads.totalAssets)
  const depositCap = requireRead(reads.depositCap)
  const name = requireRead(reads.name)
  const withdrawableTotalAssets = requireRead(reads.withdrawableTotalAssets)
  const maxDepositPercentageOfTVL = requireRead(reads.maxDepositPercentageOfTVL)
  const maxRebalanceInflow = requireRead(reads.maxRebalanceInflow)
  const maxRebalanceOutflow = requireRead(reads.maxRebalanceOutflow)

  const hasWithdrawalQueue =
    reads.withdrawalRequestId !== undefined ||
    reads.assetsInWithdrawalQueue !== undefined ||
    reads.isWithdrawalClaimRequired !== undefined
  const assetBalance = reads.assetBalance?.toString()

  return {
    address: ark,
    totalAssets: totalAssets.toString(),
    withdrawableTotalAssets: withdrawableTotalAssets.toString(),
    name: String(name),
    depositCap: depositCap.toString(),
    maxDepositPercentageOfTVL: maxDepositPercentageOfTVL.toString(),
    maxRebalanceInflow: maxRebalanceInflow.toString(),
    maxRebalanceOutflow: maxRebalanceOutflow.toString(),
    isBufferArk,
    status: getArkStatus({ isBufferArk, depositCap, totalAssets }),
    details: reads.details,
    poolBalance: reads.poolBalance?.toString() ?? null,
    ...(hasWithdrawalQueue && {
      withdrawalRequestId: reads.withdrawalRequestId?.toString(),
      assetsInWithdrawalQueue: reads.assetsInWithdrawalQueue?.toString(),
      isWithdrawalClaimRequired: reads.isWithdrawalClaimRequired,
    }),
    assetBalance,
    needsSweep: assetBalance !== undefined && assetBalance !== '0',
    ...(reads.pendingDepositAssets !== undefined && {
      pendingDepositAssets: reads.pendingDepositAssets.toString(),
    }),
    ...(reads.sharesToAssets1e18 !== undefined && {
      sharesToAssets1e18: reads.sharesToAssets1e18.toString(),
    }),
  }
}

export function buildActiveFleetsTask(harbor: Address): MultistepTask<{ fleets: unknown }> {
  return defineTask((t) => ({
    fleets: t.call({
      target: harbor,
      abi: harborCommandAbiHuman,
      functionName: 'getActiveFleetCommanders',
      optional: true,
    }),
  }))
}

export interface FleetSummaryReads {
  name: string | undefined
  symbol: string | undefined
  asset: Address | undefined
  totalAssets: bigint | undefined
  withdrawableTotalAssets: bigint | undefined
  config: unknown
  assetDecimals: number | undefined
  assetSymbol: string | undefined
}

export function buildFleetSummaryTask(fleet: Address): MultistepTask<FleetSummaryReads> {
  return defineTask((t) => {
    const asset = t.call({
      target: fleet,
      abi: fleetCommanderAbiHuman,
      functionName: 'asset',
      optional: true,
    })
    return {
      name: t.call({
        target: fleet,
        abi: fleetCommanderAbiHuman,
        functionName: 'name',
        optional: true,
      }),
      symbol: t.call({
        target: fleet,
        abi: fleetCommanderAbiHuman,
        functionName: 'symbol',
        optional: true,
      }),
      asset,
      totalAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbiHuman,
        functionName: 'totalAssets',
        optional: true,
      }),
      withdrawableTotalAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbiHuman,
        functionName: 'withdrawableTotalAssets',
        optional: true,
      }),
      config: t.call({
        target: fleet,
        abi: fleetCommanderAbiHuman,
        functionName: 'getConfig',
        optional: true,
      }),
      assetDecimals: t.call({
        target: asset as never,
        abi: erc20AbiHuman,
        functionName: 'decimals',
        optional: true,
      }),
      assetSymbol: t.call({
        target: asset as never,
        abi: erc20AbiHuman,
        functionName: 'symbol',
        optional: true,
      }),
    } as unknown as FleetSummaryReads
  }) as MultistepTask<FleetSummaryReads>
}

export function toFleetSummary(fleet: Address, reads: FleetSummaryReads): FleetSummary {
  if (
    reads.name === undefined ||
    reads.symbol === undefined ||
    reads.asset === undefined ||
    reads.totalAssets === undefined ||
    reads.withdrawableTotalAssets === undefined ||
    reads.config === undefined
  ) {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }
  if (reads.assetDecimals === undefined || reads.assetSymbol === undefined) {
    throw new ArksOverviewError('Failed to read asset contract', 502)
  }
  const config = reads.config as {
    bufferArk: Address
    minimumBufferBalance: bigint
    depositCap: bigint
    maxRebalanceOperations: bigint
    stakingRewardsManager: Address
  }
  const assetDecimals = Number(reads.assetDecimals)
  return {
    address: fleet,
    name: String(reads.name),
    symbol: String(reads.symbol),
    asset: reads.asset,
    totalAssets: reads.totalAssets.toString(),
    withdrawableTotalAssets: reads.withdrawableTotalAssets.toString(),
    depositCap: config.depositCap.toString(),
    minimumBufferBalance: config.minimumBufferBalance.toString(),
    maxRebalanceOperations: config.maxRebalanceOperations.toString(),
    assetDecimals,
    assetSymbol: String(reads.assetSymbol),
    fleetDecimals: assetDecimals,
  }
}
