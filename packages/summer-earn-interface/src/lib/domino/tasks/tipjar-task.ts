import { defineTask, type MultistepTask, runSettled, type StepExecutor } from '@halaprix/domino'

import { getHarborCommand, getTipJarInstances } from '@/app/tipjar/lib/tipJarConfig'
import { ArksOverviewError } from '@/lib/arks-overview'
import { createExecutorForChain, DEFAULT_RUN_OPTIONS } from '@/lib/domino/executor'
import { buildActiveFleetsTask } from '@/lib/domino/tasks/arks-overview-task'
import type { ChainId } from '@/types'

type Address = `0x${string}`

type RawStream = { recipient: Address; allocation: bigint; lockedUntilEpoch: bigint }

const tipJarAbiHuman = [
  'function getAllTipStreams() view returns ((address recipient, uint256 allocation, uint256 lockedUntilEpoch)[])',
  'function getTotalAllocation() view returns (uint256)',
  'function paused() view returns (bool)',
] as const

const fleetCommanderAbiHuman = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function asset() view returns (address)',
  'function balanceOf(address) view returns (uint256)',
  'function convertToAssets(uint256) view returns (uint256)',
] as const

const erc20AbiHuman = [
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
] as const

export interface TipJarInstanceReads {
  streams: readonly RawStream[] | undefined
  totalAllocation: bigint | undefined
  paused: boolean | undefined
}

export function buildTipJarInstanceTask(instance: Address): MultistepTask<TipJarInstanceReads> {
  return defineTask((t) => ({
    streams: t.call({
      target: instance,
      abi: tipJarAbiHuman,
      functionName: 'getAllTipStreams',
      optional: true,
    }),
    totalAllocation: t.call({
      target: instance,
      abi: tipJarAbiHuman,
      functionName: 'getTotalAllocation',
      optional: true,
    }),
    paused: t.call({
      target: instance,
      abi: tipJarAbiHuman,
      functionName: 'paused',
      optional: true,
    }),
  })) as MultistepTask<TipJarInstanceReads>
}

export interface TipJarFleetMetaReads {
  name: string | undefined
  symbol: string | undefined
  asset: Address | undefined
  assetDecimals: number | undefined
  assetSymbol: string | undefined
}

export function buildTipJarFleetMetaTask(fleet: Address): MultistepTask<TipJarFleetMetaReads> {
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
    } as unknown as TipJarFleetMetaReads
  }) as MultistepTask<TipJarFleetMetaReads>
}

export interface TipJarPendingReads {
  pendingShares: bigint | undefined
  pendingAssets: bigint | undefined
}

export function buildTipJarPendingTask(
  instance: Address,
  fleet: Address,
): MultistepTask<TipJarPendingReads> {
  return defineTask((t) => {
    const shares = t.call({
      target: fleet,
      abi: fleetCommanderAbiHuman,
      functionName: 'balanceOf',
      args: [instance],
      optional: true,
    })
    return {
      pendingShares: shares,
      pendingAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbiHuman,
        functionName: 'convertToAssets',
        args: [shares as never],
        optional: true,
      }),
    } as unknown as TipJarPendingReads
  }) as MultistepTask<TipJarPendingReads>
}

export interface TipjarPayload {
  chainId: ChainId
  instances: Array<{
    label: string
    address: Address
    paused: boolean
    totalAllocation: string
    streams: Array<{ recipient: Address; allocation: string; lockedUntilEpoch: string }>
    fleets: Array<{
      address: Address
      name: string
      assetSymbol: string
      assetDecimals: number
      pendingShares: string
      pendingAssets: string
    }>
  }>
}

export async function getTipjarPayload(
  chainId: ChainId,
  executor?: StepExecutor,
): Promise<TipjarPayload> {
  const instances = getTipJarInstances(chainId)
  if (instances.length === 0) {
    throw new ArksOverviewError('Unsupported chain or no TipJar deployed', 400)
  }
  const exec = executor ?? createExecutorForChain(chainId)

  const harbor = getHarborCommand(chainId)
  let activeFleets: Address[] = []
  if (harbor) {
    const [harborResult] = await runSettled(
      exec,
      [buildActiveFleetsTask(harbor as Address)],
      DEFAULT_RUN_OPTIONS,
    )
    if (harborResult.status === 'fulfilled' && harborResult.value.fleets !== undefined) {
      activeFleets = harborResult.value.fleets as Address[]
    }
  }

  const [instanceResults, metaResults, pendingResults] = await Promise.all([
    runSettled(
      exec,
      instances.map((i) => buildTipJarInstanceTask(i.address as Address)),
      DEFAULT_RUN_OPTIONS,
    ),
    runSettled(
      exec,
      activeFleets.map((f) => buildTipJarFleetMetaTask(f)),
      DEFAULT_RUN_OPTIONS,
    ),
    runSettled(
      exec,
      instances.flatMap((inst) =>
        activeFleets.map((f) => buildTipJarPendingTask(inst.address as Address, f)),
      ),
      DEFAULT_RUN_OPTIONS,
    ),
  ])

  const fleetCount = activeFleets.length
  const payloadInstances = instances.map((inst, ii) => {
    const instanceReads =
      instanceResults[ii].status === 'fulfilled'
        ? (instanceResults[ii].value as TipJarInstanceReads)
        : ({
            streams: undefined,
            totalAllocation: undefined,
            paused: undefined,
          } as TipJarInstanceReads)

    const fleets = activeFleets.map((fleetAddress, fi) => {
      const metaRes = metaResults[fi]
      const meta =
        metaRes.status === 'fulfilled'
          ? (metaRes.value as TipJarFleetMetaReads)
          : ({} as TipJarFleetMetaReads)
      const pendingRes = pendingResults[ii * fleetCount + fi]
      const pending =
        pendingRes.status === 'fulfilled'
          ? (pendingRes.value as TipJarPendingReads)
          : ({} as TipJarPendingReads)
      return {
        address: fleetAddress,
        name: meta.name !== undefined ? String(meta.name) : 'Unknown fleet',
        assetSymbol: String(meta.assetSymbol ?? '') || String(meta.symbol ?? ''),
        assetDecimals: meta.assetDecimals !== undefined ? Number(meta.assetDecimals) : 18,
        pendingShares: (pending.pendingShares ?? 0n).toString(),
        pendingAssets: (pending.pendingAssets ?? 0n).toString(),
      }
    })

    return {
      label: inst.label,
      address: inst.address as Address,
      paused: Boolean(instanceReads.paused ?? false),
      totalAllocation: (instanceReads.totalAllocation ?? 0n).toString(),
      streams: (instanceReads.streams ?? []).map((s) => ({
        recipient: s.recipient,
        allocation: s.allocation.toString(),
        lockedUntilEpoch: s.lockedUntilEpoch.toString(),
      })),
      fleets,
    }
  })

  return { chainId, instances: payloadInstances }
}
