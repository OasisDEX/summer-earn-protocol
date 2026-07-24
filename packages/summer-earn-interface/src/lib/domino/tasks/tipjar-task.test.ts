import { runSettled } from '@halaprix/domino'

import { callKey, FAIL, MockStepExecutor } from '../testing/mock-executor'
import { buildTipJarPendingTask, getTipjarPayload } from './tipjar-task'

jest.mock('@/app/tipjar/lib/tipJarConfig', () => ({
  getTipJarInstances: (chainId: string) => {
    if (chainId === '8453') {
      return [{ label: 'TipJar v1', address: '0x7191000000000000000000000000000000000071' }]
    }
    if (chainId === '1') {
      return [
        { label: 'TipJar Inst 1', address: '0x1111111111111111111111111111111111111111' },
        { label: 'TipJar Inst 2', address: '0x2222222222222222222222222222222222222222' },
      ]
    }
    return []
  },
  getHarborCommand: (chainId: string) => {
    if (chainId === '8453') return '0x4A4B04000000000000000000000000000000004A'
    if (chainId === '1') return '0x4A4B04000000000000000000000000000000004B'
    return null
  },
}))

const TIPJAR = '0x7191000000000000000000000000000000000071' as const
const HARBOR = '0x4A4B04000000000000000000000000000000004A' as const
const FLEET = '0xF1EE7000000000000000000000000000000000F1' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const

const STREAM = {
  recipient: '0x0000000000000000000000000000000000000009' as const,
  allocation: 250n,
  lockedUntilEpoch: 12n,
}

const happyHandlers = {
  [callKey(HARBOR, 'getActiveFleetCommanders')]: [FLEET],
  [callKey(TIPJAR, 'getAllTipStreams')]: [STREAM],
  [callKey(TIPJAR, 'getTotalAllocation')]: 250n,
  [callKey(TIPJAR, 'paused')]: false,
  [callKey(FLEET, 'name')]: 'Fleet One',
  [callKey(FLEET, 'symbol')]: 'FL1',
  [callKey(FLEET, 'asset')]: ASSET,
  [callKey(ASSET, 'decimals')]: 6,
  [callKey(ASSET, 'symbol')]: 'USDC',
  [callKey(FLEET, 'balanceOf')]: 500n,
  [callKey(FLEET, 'convertToAssets')]: (args: readonly unknown[] | undefined) =>
    args?.[0] === 500n ? 510n : 0n,
}

describe('buildTipJarPendingTask', () => {
  it('feeds the balanceOf result into convertToAssets via a ref arg', async () => {
    const executor = new MockStepExecutor(happyHandlers)
    const [result] = await runSettled(executor, [buildTipJarPendingTask(TIPJAR, FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    expect(result.value).toEqual({ pendingShares: 500n, pendingAssets: 510n })
    expect(executor.batches).toHaveLength(2)
  })

  it('skips convertToAssets when balanceOf fails', async () => {
    const executor = new MockStepExecutor({ ...happyHandlers, [callKey(FLEET, 'balanceOf')]: FAIL })
    const [result] = await runSettled(executor, [buildTipJarPendingTask(TIPJAR, FLEET)])
    if (result.status !== 'fulfilled') throw new Error('expected fulfilled')
    expect(result.value).toEqual({ pendingShares: undefined, pendingAssets: undefined })
  })
})

describe('getTipjarPayload', () => {
  it('throws 400 for a chain with no TipJar', async () => {
    await expect(getTipjarPayload('99' as never, new MockStepExecutor({}))).rejects.toMatchObject({
      message: 'Unsupported chain or no TipJar deployed',
      status: 400,
    })
  })

  it('throws 502 when all instance reads fail (total RPC outage)', async () => {
    const executor = new MockStepExecutor({
      [callKey(HARBOR, 'getActiveFleetCommanders')]: [FLEET],
      [callKey(TIPJAR, 'getAllTipStreams')]: FAIL,
      [callKey(TIPJAR, 'getTotalAllocation')]: FAIL,
      [callKey(TIPJAR, 'paused')]: FAIL,
    })
    await expect(getTipjarPayload('8453' as never, executor)).rejects.toMatchObject({
      message: 'Failed to read tipjar data',
      status: 502,
    })
  })

  it('assembles the exact legacy payload on the happy path', async () => {
    const payload = await getTipjarPayload('8453' as never, new MockStepExecutor(happyHandlers))
    expect(payload).toEqual({
      chainId: '8453',
      instances: [
        {
          label: 'TipJar v1',
          address: TIPJAR,
          paused: false,
          totalAllocation: '250',
          streams: [{ recipient: STREAM.recipient, allocation: '250', lockedUntilEpoch: '12' }],
          fleets: [
            {
              address: FLEET,
              name: 'Fleet One',
              assetSymbol: 'USDC',
              assetDecimals: 6,
              pendingShares: '500',
              pendingAssets: '510',
            },
          ],
        },
      ],
    })
  })

  it('correctly maps matrix indexing for 2 instances x 2 fleets with distinct per-pair balances', async () => {
    const INST1 = '0x1111111111111111111111111111111111111111' as const
    const INST2 = '0x2222222222222222222222222222222222222222' as const
    const HARBOR_MAIN = '0x4A4B04000000000000000000000000000000004B' as const
    const F1 = '0xF100000000000000000000000000000000000001' as const
    const F2 = '0xF200000000000000000000000000000000000002' as const

    const matrixHandlers = {
      [callKey(HARBOR_MAIN, 'getActiveFleetCommanders')]: [F1, F2],
      // Inst 1
      [callKey(INST1, 'getAllTipStreams')]: [],
      [callKey(INST1, 'getTotalAllocation')]: 100n,
      [callKey(INST1, 'paused')]: false,
      // Inst 2
      [callKey(INST2, 'getAllTipStreams')]: [],
      [callKey(INST2, 'getTotalAllocation')]: 200n,
      [callKey(INST2, 'paused')]: false,
      // Fleet meta
      [callKey(F1, 'name')]: 'Fleet 1',
      [callKey(F1, 'symbol')]: 'F1',
      [callKey(F1, 'asset')]: ASSET,
      [callKey(F2, 'name')]: 'Fleet 2',
      [callKey(F2, 'symbol')]: 'F2',
      [callKey(F2, 'asset')]: ASSET,
      [callKey(ASSET, 'decimals')]: 18,
      [callKey(ASSET, 'symbol')]: 'DAI',
      // Balances per (inst, fleet) pair
      // F1.balanceOf(INST1) = 100n -> convertToAssets(100n) = 101n
      // F2.balanceOf(INST1) = 200n -> convertToAssets(200n) = 202n
      // F1.balanceOf(INST2) = 300n -> convertToAssets(300n) = 303n
      // F2.balanceOf(INST2) = 400n -> convertToAssets(400n) = 404n
      [callKey(F1, 'balanceOf')]: (args: readonly unknown[] | undefined) => {
        if (args?.[0] === INST1) return 100n
        if (args?.[0] === INST2) return 300n
        return 0n
      },
      [callKey(F2, 'balanceOf')]: (args: readonly unknown[] | undefined) => {
        if (args?.[0] === INST1) return 200n
        if (args?.[0] === INST2) return 400n
        return 0n
      },
      [callKey(F1, 'convertToAssets')]: (args: readonly unknown[] | undefined) => {
        if (args?.[0] === 100n) return 101n
        if (args?.[0] === 300n) return 303n
        return 0n
      },
      [callKey(F2, 'convertToAssets')]: (args: readonly unknown[] | undefined) => {
        if (args?.[0] === 200n) return 202n
        if (args?.[0] === 400n) return 404n
        return 0n
      },
    }

    const payload = await getTipjarPayload('1' as never, new MockStepExecutor(matrixHandlers))
    expect(payload.instances).toHaveLength(2)

    // Inst 1
    const inst1Fleets = payload.instances[0].fleets
    expect(inst1Fleets[0]).toMatchObject({
      address: F1,
      pendingShares: '100',
      pendingAssets: '101',
    })
    expect(inst1Fleets[1]).toMatchObject({
      address: F2,
      pendingShares: '200',
      pendingAssets: '202',
    })

    // Inst 2
    const inst2Fleets = payload.instances[1].fleets
    expect(inst2Fleets[0]).toMatchObject({
      address: F1,
      pendingShares: '300',
      pendingAssets: '303',
    })
    expect(inst2Fleets[1]).toMatchObject({
      address: F2,
      pendingShares: '400',
      pendingAssets: '404',
    })
  })

  it('applies legacy defaults on partial failures (unknown fleet, 18 decimals, zero pendings, empty streams)', async () => {
    const executor = new MockStepExecutor({
      ...happyHandlers,
      [callKey(TIPJAR, 'getAllTipStreams')]: FAIL,
      [callKey(TIPJAR, 'getTotalAllocation')]: FAIL,
      [callKey(TIPJAR, 'paused')]: false, // one read succeeds so not a total outage
      [callKey(FLEET, 'name')]: FAIL,
      [callKey(FLEET, 'symbol')]: FAIL,
      [callKey(FLEET, 'asset')]: FAIL,
      [callKey(FLEET, 'balanceOf')]: FAIL,
    })
    const payload = await getTipjarPayload('8453' as never, executor)
    const instance = payload.instances[0]
    expect(instance.paused).toBe(false)
    expect(instance.totalAllocation).toBe('0')
    expect(instance.streams).toEqual([])
    expect(instance.fleets[0]).toEqual({
      address: FLEET,
      name: 'Unknown fleet',
      assetSymbol: '',
      assetDecimals: 18,
      pendingShares: '0',
      pendingAssets: '0',
    })
  })

  it('returns instances with empty fleets when the harbor read fails', async () => {
    const executor = new MockStepExecutor({
      ...happyHandlers,
      [callKey(HARBOR, 'getActiveFleetCommanders')]: FAIL,
    })
    const payload = await getTipjarPayload('8453' as never, executor)
    expect(payload.instances[0].fleets).toEqual([])
  })
})
