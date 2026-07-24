import { runSettled } from '@halaprix/domino'

import { ArksOverviewError } from '@/lib/arks-overview'
import { callKey, FAIL, MockStepExecutor } from '../testing/mock-executor'
import {
  buildActiveFleetsTask,
  buildArkOverviewTask,
  buildFleetArksIndexTask,
  buildFleetSummaryTask,
  toArkOverview,
  toFleetSummary,
  type ArkReads,
  type FleetSummaryReads,
} from './arks-overview-task'

const FLEET = '0xF1EE7000000000000000000000000000000000F1' as const
const ARK = '0xA4B0000000000000000000000000000000000001' as const
const BUFFER = '0xA4B0000000000000000000000000000000000002' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const
const POOL = '0x9001000000000000000000000000000000009001' as const
const HARBOR = '0x4A4B04000000000000000000000000000000004A' as const

function arkHandlers(overrides: Record<string, unknown> = {}) {
  return {
    [callKey(ARK, 'totalAssets')]: 1000n,
    [callKey(ARK, 'withdrawableTotalAssets')]: 900n,
    [callKey(ARK, 'name')]: 'Test Ark',
    [callKey(ARK, 'depositCap')]: 5000n,
    [callKey(ARK, 'maxDepositPercentageOfTVL')]: 100n,
    [callKey(ARK, 'maxRebalanceInflow')]: 10n,
    [callKey(ARK, 'maxRebalanceOutflow')]: 20n,
    [callKey(ARK, 'withdrawalRequestId')]: FAIL,
    [callKey(ARK, 'assetsInWithdrawalQueue')]: FAIL,
    [callKey(ARK, 'isWithdrawalClaimRequired')]: FAIL,
    [callKey(ARK, 'pendingDepositAssets')]: FAIL,
    [callKey(ARK, 'sharesToAssets')]: FAIL,
    [callKey(ARK, 'details')]: JSON.stringify({ protocol: 'ERC4626', pool: POOL, chainId: 1 }),
    [callKey(ASSET, 'balanceOf')]: 7n,
    [callKey(POOL, 'balanceOf')]: 333n,
    ...overrides,
  }
}

describe('buildFleetArksIndexTask', () => {
  it('reads activeArks, bufferArk and asset in one step', async () => {
    const executor = new MockStepExecutor({
      [callKey(FLEET, 'getActiveArks')]: [ARK],
      [callKey(FLEET, 'bufferArk')]: BUFFER,
      [callKey(FLEET, 'asset')]: ASSET,
    })
    const [result] = await runSettled(executor, [buildFleetArksIndexTask(FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') {
      expect(result.value).toEqual({ activeArks: [ARK], bufferArk: BUFFER, asset: ASSET })
    }
    expect(executor.batches).toHaveLength(1)
  })

  it('demotes a failed asset read to undefined instead of failing the task', async () => {
    const executor = new MockStepExecutor({
      [callKey(FLEET, 'getActiveArks')]: [ARK],
      [callKey(FLEET, 'bufferArk')]: BUFFER,
      [callKey(FLEET, 'asset')]: FAIL,
    })
    const [result] = await runSettled(executor, [buildFleetArksIndexTask(FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') expect(result.value.asset).toBeUndefined()
  })
})

describe('buildArkOverviewTask', () => {
  it('resolves base reads, details, asset balance and pool balance (pool via derived target)', async () => {
    const executor = new MockStepExecutor(arkHandlers())
    const [result] = await runSettled(executor, [
      buildArkOverviewTask({ ark: ARK, fleetAsset: ASSET }),
    ])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    const reads = result.value as ArkReads
    expect(reads.totalAssets).toBe(1000n)
    expect(reads.details).toEqual({ protocol: 'ERC4626', pool: POOL, chainId: 1 })
    expect(reads.assetBalance).toBe(7n)
    expect(reads.poolBalance).toBe(333n)
    expect(executor.batches).toHaveLength(2)
  })

  it('skips the pool balance call when details() fails or has no resolvable pool', async () => {
    const executor = new MockStepExecutor(arkHandlers({ [callKey(ARK, 'details')]: FAIL }))
    const [result] = await runSettled(executor, [
      buildArkOverviewTask({ ark: ARK, fleetAsset: ASSET }),
    ])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    const reads = result.value as ArkReads
    expect(reads.details).toBeNull()
    expect(reads.poolBalance).toBeUndefined()
  })

  it('omits the asset balanceOf call when the fleet has no readable asset', async () => {
    const executor = new MockStepExecutor(arkHandlers())
    const [result] = await runSettled(executor, [
      buildArkOverviewTask({ ark: ARK, fleetAsset: null }),
    ])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    expect((result.value as ArkReads).assetBalance).toBeUndefined()
  })
})

describe('toArkOverview', () => {
  const baseReads: ArkReads = {
    totalAssets: 1000n,
    withdrawableTotalAssets: 900n,
    name: 'Test Ark',
    depositCap: 5000n,
    maxDepositPercentageOfTVL: 100n,
    maxRebalanceInflow: 10n,
    maxRebalanceOutflow: 20n,
    withdrawalRequestId: undefined,
    assetsInWithdrawalQueue: undefined,
    isWithdrawalClaimRequired: undefined,
    pendingDepositAssets: undefined,
    sharesToAssets1e18: undefined,
    assetBalance: 7n,
    details: { protocol: 'ERC4626', pool: POOL, chainId: 1 },
    poolBalance: 333n,
  }

  it('produces the legacy ArkOverview shape (bigints stringified, needsSweep derived)', () => {
    expect(toArkOverview(ARK, false, baseReads)).toEqual({
      address: ARK,
      totalAssets: '1000',
      withdrawableTotalAssets: '900',
      name: 'Test Ark',
      depositCap: '5000',
      maxDepositPercentageOfTVL: '100',
      maxRebalanceInflow: '10',
      maxRebalanceOutflow: '20',
      isBufferArk: false,
      status: 'active',
      details: { protocol: 'ERC4626', pool: POOL, chainId: 1 },
      poolBalance: '333',
      assetBalance: '7',
      needsSweep: true,
    })
  })

  it('includes withdrawal-queue keys only when at least one queue read succeeded', () => {
    const withQueue = toArkOverview(ARK, false, {
      ...baseReads,
      withdrawalRequestId: 3n,
      assetsInWithdrawalQueue: 50n,
      isWithdrawalClaimRequired: false,
    })
    expect(withQueue.withdrawalRequestId).toBe('3')
    expect(withQueue.assetsInWithdrawalQueue).toBe('50')
    expect(withQueue.isWithdrawalClaimRequired).toBe(false)
    expect('withdrawalRequestId' in toArkOverview(ARK, false, baseReads)).toBe(false)
  })

  it('includes wisdomtree keys only when present, and marks statuses', () => {
    const wt = toArkOverview(ARK, false, {
      ...baseReads,
      pendingDepositAssets: 5n,
      sharesToAssets1e18: 2000000000000000000n,
      depositCap: 0n,
      totalAssets: 0n,
      assetBalance: 0n,
    })
    expect(wt.pendingDepositAssets).toBe('5')
    expect(wt.sharesToAssets1e18).toBe('2000000000000000000')
    expect(wt.status).toBe('ready-to-remove')
    expect(wt.needsSweep).toBe(false)
    expect(toArkOverview(ARK, true, baseReads).status).toBe('active')
    expect(toArkOverview(ARK, true, baseReads).isBufferArk).toBe(true)
  })

  it('throws ArksOverviewError(502) when a required base read is missing', () => {
    expect(() =>
      toArkOverview(ARK, false, { ...baseReads, totalAssets: undefined as unknown as bigint }),
    ).toThrow(ArksOverviewError)
    try {
      toArkOverview(ARK, false, { ...baseReads, name: undefined as unknown as string })
    } catch (err) {
      expect((err as ArksOverviewError).message).toBe('Failed to read ark data')
      expect((err as ArksOverviewError).status).toBe(502)
    }
  })

  it('keeps poolBalance null when the pool read did not resolve', () => {
    const result = toArkOverview(ARK, false, { ...baseReads, poolBalance: undefined })
    expect(result.poolBalance).toBeNull()
  })
})

describe('buildActiveFleetsTask', () => {
  it('reads getActiveFleetCommanders', async () => {
    const executor = new MockStepExecutor({
      [callKey(HARBOR, 'getActiveFleetCommanders')]: [FLEET],
    })
    const [result] = await runSettled(executor, [buildActiveFleetsTask(HARBOR)])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') expect(result.value.fleets).toEqual([FLEET])
  })
})

describe('buildFleetSummaryTask + toFleetSummary', () => {
  const config = {
    bufferArk: BUFFER,
    minimumBufferBalance: 100n,
    depositCap: 9000n,
    maxRebalanceOperations: 4n,
    stakingRewardsManager: '0x0000000000000000000000000000000000000001',
  }
  const handlers = {
    [callKey(FLEET, 'name')]: 'Fleet One',
    [callKey(FLEET, 'symbol')]: 'FL1',
    [callKey(FLEET, 'asset')]: ASSET,
    [callKey(FLEET, 'totalAssets')]: 12345n,
    [callKey(FLEET, 'withdrawableTotalAssets')]: 12000n,
    [callKey(FLEET, 'getConfig')]: config,
    [callKey(ASSET, 'decimals')]: 6,
    [callKey(ASSET, 'symbol')]: 'USDC',
  }

  it('resolves fleet + nested asset reads in two round-trips and assembles FleetSummary', async () => {
    const executor = new MockStepExecutor(handlers)
    const [result] = await runSettled(executor, [buildFleetSummaryTask(FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    expect(executor.batches).toHaveLength(2)
    expect(toFleetSummary(FLEET, result.value as FleetSummaryReads)).toEqual({
      address: FLEET,
      name: 'Fleet One',
      symbol: 'FL1',
      asset: ASSET,
      totalAssets: '12345',
      withdrawableTotalAssets: '12000',
      depositCap: '9000',
      minimumBufferBalance: '100',
      maxRebalanceOperations: '4',
      assetDecimals: 6,
      assetSymbol: 'USDC',
      fleetDecimals: 6,
    })
  })

  it('maps a fleet-level failure to the legacy fleet error', async () => {
    const executor = new MockStepExecutor({ ...handlers, [callKey(FLEET, 'name')]: FAIL })
    const [result] = await runSettled(executor, [buildFleetSummaryTask(FLEET)])
    if (result.status !== 'fulfilled') throw new Error('expected fulfilled')
    expect(() => toFleetSummary(FLEET, result.value as FleetSummaryReads)).toThrow(
      'Failed to read fleet contract',
    )
  })

  it('maps an asset-level failure to the legacy asset error', async () => {
    const executor = new MockStepExecutor({ ...handlers, [callKey(ASSET, 'decimals')]: FAIL })
    const [result] = await runSettled(executor, [buildFleetSummaryTask(FLEET)])
    if (result.status !== 'fulfilled') throw new Error('expected fulfilled')
    expect(() => toFleetSummary(FLEET, result.value as FleetSummaryReads)).toThrow(
      'Failed to read asset contract',
    )
  })
})
