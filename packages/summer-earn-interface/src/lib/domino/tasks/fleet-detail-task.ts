import { defineTask, runSettled, type MultistepTask, type StepExecutor } from '@halaprix/domino'
import { getAddress } from 'viem'

import { CHAIN_RPC_URLS } from '@/config/chains'
import { ArksOverviewError } from '@/lib/arks-overview'
import { createExecutorForChain, DEFAULT_RUN_OPTIONS } from '@/lib/domino/executor'

type Address = `0x${string}`

const fleetCommanderAbiHuman = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function asset() view returns (address)',
  'function totalAssets() view returns (uint256)',
  'function withdrawableTotalAssets() view returns (uint256)',
  'function decimals() view returns (uint8)',
  'function getConfig() view returns ((address bufferArk, uint256 minimumBufferBalance, uint256 depositCap, uint256 maxRebalanceOperations, address stakingRewardsManager))',
  'function balanceOf(address) view returns (uint256)',
] as const

const erc20AbiHuman = [
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function balanceOf(address) view returns (uint256)',
  'function allowance(address,address) view returns (uint256)',
] as const

export interface FleetDetailReads {
  name: string | undefined
  symbol: string | undefined
  asset: Address | undefined
  totalAssets: bigint | undefined
  withdrawableTotalAssets: bigint | undefined
  fleetDecimals: number | undefined
  config: unknown
  assetDecimals: number | undefined
  assetSymbol: string | undefined
  userBalance: bigint | undefined
  userUnderlyingBalance: bigint | undefined
  userAllowance: bigint | undefined
}

export function buildFleetDetailTask(
  fleet: Address,
  user: Address | null,
): MultistepTask<FleetDetailReads> {
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
      fleetDecimals: t.call({
        target: fleet,
        abi: fleetCommanderAbiHuman,
        functionName: 'decimals',
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
      userBalance: user
        ? t.call({
            target: fleet,
            abi: fleetCommanderAbiHuman,
            functionName: 'balanceOf',
            args: [user],
            optional: true,
          })
        : undefined,
      userUnderlyingBalance: user
        ? t.call({
            target: asset as never,
            abi: erc20AbiHuman,
            functionName: 'balanceOf',
            args: [user],
            optional: true,
          })
        : undefined,
      userAllowance: user
        ? t.call({
            target: asset as never,
            abi: erc20AbiHuman,
            functionName: 'allowance',
            args: [user, fleet],
            optional: true,
          })
        : undefined,
    } as unknown as FleetDetailReads
  }) as MultistepTask<FleetDetailReads>
}

export interface FleetDetailPayload {
  address: string
  name: string
  symbol: string
  asset: Address
  totalAssets: string
  withdrawableTotalAssets: string
  depositCap: string
  minimumBufferBalance: string
  maxRebalanceOperations: string
  assetDecimals: number
  assetSymbol: string
  fleetDecimals: number
  userInfo: { balance: string; underlyingBalance: string; allowance: string } | null
}

export async function getFleetDetailPayload(
  chainId: string,
  address: string,
  user: string | null,
  executor?: StepExecutor,
): Promise<FleetDetailPayload> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) throw new ArksOverviewError('Unsupported chainId', 400)
  const exec = executor ?? createExecutorForChain(chainId)
  const fleetAddr = getAddress(address)

  const [result] = await runSettled(
    exec,
    [buildFleetDetailTask(fleetAddr, (user as Address | null) ?? null)],
    DEFAULT_RUN_OPTIONS,
  )
  if (result.status === 'rejected') {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }
  const reads = result.value as FleetDetailReads

  if (
    reads.name === undefined ||
    reads.symbol === undefined ||
    reads.asset === undefined ||
    reads.totalAssets === undefined ||
    reads.withdrawableTotalAssets === undefined ||
    reads.fleetDecimals === undefined ||
    reads.config === undefined
  ) {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }
  if (reads.assetDecimals === undefined || reads.assetSymbol === undefined) {
    throw new ArksOverviewError('Failed to read asset contract', 502)
  }

  let userInfo: FleetDetailPayload['userInfo'] = null
  if (user) {
    if (
      reads.userBalance === undefined ||
      reads.userUnderlyingBalance === undefined ||
      reads.userAllowance === undefined
    ) {
      throw new ArksOverviewError('Failed to read user info', 502)
    }
    userInfo = {
      balance: reads.userBalance.toString(),
      underlyingBalance: reads.userUnderlyingBalance.toString(),
      allowance: reads.userAllowance.toString(),
    }
  }

  const config = reads.config as {
    bufferArk: Address
    minimumBufferBalance: bigint
    depositCap: bigint
    maxRebalanceOperations: bigint
    stakingRewardsManager: Address
  }

  return {
    address,
    name: String(reads.name),
    symbol: String(reads.symbol),
    asset: reads.asset,
    totalAssets: reads.totalAssets.toString(),
    withdrawableTotalAssets: reads.withdrawableTotalAssets.toString(),
    depositCap: config.depositCap.toString(),
    minimumBufferBalance: config.minimumBufferBalance.toString(),
    maxRebalanceOperations: config.maxRebalanceOperations.toString(),
    assetDecimals: Number(reads.assetDecimals),
    assetSymbol: String(reads.assetSymbol),
    fleetDecimals: Number(reads.fleetDecimals),
    userInfo,
  }
}
