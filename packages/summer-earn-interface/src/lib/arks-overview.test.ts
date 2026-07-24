import {
  computeBufferSharePct,
  getArkStatus,
  getArksForFleet,
  getFleetsForChain,
  parseArkDetails,
} from './arks-overview'
import { callKey, FAIL, MockStepExecutor } from './domino/testing/mock-executor'

const FLEET = '0xF1EE7000000000000000000000000000000000F1' as const
const ARK = '0xA4B0000000000000000000000000000000000001' as const
const BUFFER = '0xA4B0000000000000000000000000000000000002' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const
const HARBOR_8453 = '0x09eb323dBFECB43fd746c607A9321dACdfB0140F' as const

describe('getArkStatus', () => {
  it('returns active for a buffer ark regardless of cap/assets', () => {
    expect(getArkStatus({ isBufferArk: true, depositCap: 0n, totalAssets: 500n })).toBe('active')
  })

  it('returns active when depositCap is greater than zero', () => {
    expect(getArkStatus({ isBufferArk: false, depositCap: 100n, totalAssets: 0n })).toBe('active')
  })

  it('returns ready-to-remove when cap is zero and assets are fully drained', () => {
    expect(getArkStatus({ isBufferArk: false, depositCap: 0n, totalAssets: 0n })).toBe(
      'ready-to-remove',
    )
  })

  it('returns stuck-needs-sweep when cap is zero but assets remain', () => {
    expect(getArkStatus({ isBufferArk: false, depositCap: 0n, totalAssets: 42n })).toBe(
      'stuck-needs-sweep',
    )
  })
})

describe('parseArkDetails', () => {
  it('returns null for undefined input', () => {
    expect(parseArkDetails(undefined)).toBeNull()
  })

  it('returns null for invalid JSON', () => {
    expect(parseArkDetails('{not json')).toBeNull()
  })

  it('extracts protocol, pool, and chainId when all are valid', () => {
    const json = JSON.stringify({
      protocol: 'ERC4626',
      pool: '0x1234567890123456789012345678901234567890',
      chainId: 1,
    })
    expect(parseArkDetails(json)).toEqual({
      protocol: 'ERC4626',
      pool: '0x1234567890123456789012345678901234567890',
      chainId: 1,
    })
  })

  it('omits pool when it is not a 20-byte hex address (e.g. a Morpho Blue bytes32 market id)', () => {
    const json = JSON.stringify({
      protocol: 'MorphoBlue',
      pool: '0x1234567890123456789012345678901234567890123456789012345678901234567890',
      chainId: 1,
    })
    const result = parseArkDetails(json)
    expect(result?.pool).toBeUndefined()
    expect(result?.protocol).toBe('MorphoBlue')
  })

  it('omits fields with the wrong type instead of throwing', () => {
    const json = JSON.stringify({ protocol: 123, pool: null, chainId: '1' })
    expect(parseArkDetails(json)).toEqual({
      protocol: undefined,
      pool: undefined,
      chainId: undefined,
    })
  })
})

describe('getArkStatus integration with parsed details', () => {
  it('a ready-to-remove non-buffer ark with an unresolvable pool still gets a status', () => {
    const details = parseArkDetails(
      JSON.stringify({
        protocol: 'MorphoBlue',
        pool: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', // 32-byte market id, not an address
      }),
    )
    expect(details?.pool).toBeUndefined()
    const status = getArkStatus({ isBufferArk: false, depositCap: 0n, totalAssets: 0n })
    expect(status).toBe('ready-to-remove')
  })
})

describe('computeBufferSharePct', () => {
  it('returns null when fleet total assets are zero (avoid divide-by-zero)', () => {
    expect(computeBufferSharePct(0n, 0n)).toBeNull()
  })

  it('returns 100 when the buffer ark holds the entire fleet TVL', () => {
    expect(computeBufferSharePct(1000n, 1000n)).toBe(100)
  })

  it('returns a rounded-to-2-decimals percentage', () => {
    expect(computeBufferSharePct(1n, 3n)).toBe(33.33)
  })
})

const arkReads = (ark: string) => ({
  [callKey(ark, 'totalAssets')]: 100n,
  [callKey(ark, 'withdrawableTotalAssets')]: 90n,
  [callKey(ark, 'name')]: `ark-${ark.slice(-1)}`,
  [callKey(ark, 'depositCap')]: 1000n,
  [callKey(ark, 'maxDepositPercentageOfTVL')]: 50n,
  [callKey(ark, 'maxRebalanceInflow')]: 1n,
  [callKey(ark, 'maxRebalanceOutflow')]: 2n,
  [callKey(ark, 'withdrawalRequestId')]: FAIL,
  [callKey(ark, 'assetsInWithdrawalQueue')]: FAIL,
  [callKey(ark, 'isWithdrawalClaimRequired')]: FAIL,
  [callKey(ark, 'pendingDepositAssets')]: FAIL,
  [callKey(ark, 'sharesToAssets')]: FAIL,
  [callKey(ark, 'details')]: FAIL,
})

describe('getArksForFleet (domino path, injected executor)', () => {
  const handlers = {
    [callKey(FLEET, 'getActiveArks')]: [ARK],
    [callKey(FLEET, 'bufferArk')]: BUFFER,
    [callKey(FLEET, 'asset')]: ASSET,
    [callKey(ASSET, 'balanceOf')]: 0n,
    ...arkReads(ARK),
    ...arkReads(BUFFER),
  }

  it('returns active arks + buffer ark last, with legacy shape', async () => {
    const arks = await getArksForFleet('8453', FLEET, new MockStepExecutor(handlers))
    expect(arks).toHaveLength(2)
    expect(arks[0].address).toBe(ARK)
    expect(arks[1].address).toBe(BUFFER)
    expect(arks[1].isBufferArk).toBe(true)
    expect(arks[0]).toMatchObject({
      totalAssets: '100',
      status: 'active',
      details: null,
      poolBalance: null,
      needsSweep: false,
      assetBalance: '0',
    })
    expect(arks[0]).not.toHaveProperty('withdrawalRequestId')
  })

  it('throws 502 when fleet index reads fail', async () => {
    const executor = new MockStepExecutor({
      ...handlers,
      [callKey(FLEET, 'getActiveArks')]: FAIL,
    })
    await expect(getArksForFleet('8453', FLEET, executor)).rejects.toThrow(
      'Failed to read fleet arks',
    )
  })

  it('throws 502 when any ark base read fails', async () => {
    const executor = new MockStepExecutor({
      ...handlers,
      [callKey(ARK, 'totalAssets')]: FAIL,
    })
    await expect(getArksForFleet('8453', FLEET, executor)).rejects.toThrow(
      'Failed to read ark data',
    )
  })

  it('throws 400 for an unsupported chainId without touching the executor', async () => {
    await expect(getArksForFleet('42', FLEET)).rejects.toMatchObject({
      message: 'Unsupported chainId',
      status: 400,
    })
  })
})

describe('getFleetsForChain (domino path, injected executor)', () => {
  it('appends the hard-coded Base fleet on chain 8453', async () => {
    const EXTRA = '0x29f13a877F3d1A14AC0B15B07536D4423b35E198'
    const fleetHandlers = (fleet: string) => ({
      [callKey(fleet, 'name')]: 'F',
      [callKey(fleet, 'symbol')]: 'F',
      [callKey(fleet, 'asset')]: ASSET,
      [callKey(fleet, 'totalAssets')]: 1n,
      [callKey(fleet, 'withdrawableTotalAssets')]: 1n,
      [callKey(fleet, 'getConfig')]: {
        bufferArk: BUFFER,
        minimumBufferBalance: 0n,
        depositCap: 0n,
        maxRebalanceOperations: 0n,
        stakingRewardsManager: ASSET,
      },
    })
    const executor = new MockStepExecutor({
      [callKey(HARBOR_8453, 'getActiveFleetCommanders')]: [FLEET],
      [callKey(ASSET, 'decimals')]: 6,
      [callKey(ASSET, 'symbol')]: 'USDC',
      ...fleetHandlers(FLEET),
      ...fleetHandlers(EXTRA),
    })
    const fleets = await getFleetsForChain('8453', 'production', executor)
    expect(fleets.map((f) => f.address)).toEqual([FLEET, EXTRA])
    expect(fleets[0].assetDecimals).toBe(6)
  })
})
