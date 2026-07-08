import { computeBufferSharePct, getArkStatus, parseArkDetails } from './arks-overview'

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
