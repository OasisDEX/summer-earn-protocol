import { runSettled } from '@halaprix/domino'

import { callKey, FAIL, MockStepExecutor } from '../testing/mock-executor'
import { buildTipJarPendingTask, getTipjarPayload } from './tipjar-task'

jest.mock('@/app/tipjar/lib/tipJarConfig', () => ({
  getTipJarInstances: (chainId: string) =>
    chainId === '8453'
      ? [{ label: 'TipJar v1', address: '0x7191000000000000000000000000000000000071' }]
      : [],
  getHarborCommand: (chainId: string) =>
    chainId === '8453' ? '0x4A4B04000000000000000000000000000000004A' : null,
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
    await expect(getTipjarPayload('1' as never, new MockStepExecutor({}))).rejects.toMatchObject({
      message: 'Unsupported chain or no TipJar deployed',
      status: 400,
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

  it('applies legacy defaults on partial failures (unknown fleet, 18 decimals, zero pendings, empty streams)', async () => {
    const executor = new MockStepExecutor({
      ...happyHandlers,
      [callKey(TIPJAR, 'getAllTipStreams')]: FAIL,
      [callKey(TIPJAR, 'getTotalAllocation')]: FAIL,
      [callKey(TIPJAR, 'paused')]: FAIL,
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
