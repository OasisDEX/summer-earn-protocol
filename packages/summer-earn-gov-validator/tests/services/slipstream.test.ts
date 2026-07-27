import { getWrappedSlipstreamTokenAmounts } from '@/services/slipstream'

const POOL = '0x1111111111111111111111111111111111111111'
const GAUGE = '0x2222222222222222222222222222222222222222'
const NFPM = '0x3333333333333333333333333333333333333333'
const WRAPPER = '0x4444444444444444444444444444444444444444'
const OWNER = '0x5555555555555555555555555555555555555555'
const OTHER = '0x6666666666666666666666666666666666666666'
const TOKEN0 = '0x7777777777777777777777777777777777777777'
const TOKEN1 = '0x8888888888888888888888888888888888888888'

const Q96 = 1n << 96n

type Call = { address: string; functionName: string; args?: readonly unknown[] }

// In-range position: sqrtP == Q96 (tick 0), range [-600, 600] => both amounts > 0.
function makePosition(liquidity: bigint) {
  return [0n, OTHER, TOKEN0, TOKEN1, 10, -600, 600, liquidity, 0n, 0n, 0n, 0n]
}

const readContractMock = jest.fn()

jest.mock('@/config/rpc', () => ({
  getPublicClient: () => ({
    readContract: (call: Call) => readContractMock(call),
  }),
}))

function installHandlers(overrides: {
  stakedIds?: bigint[]
  ownerOf?: (id: bigint) => string
  positions?: (id: bigint) => unknown[]
  slot0Error?: boolean
}) {
  const {
    stakedIds = [1n, 2n],
    ownerOf = (id) => (id === 1n ? OWNER : OTHER),
    positions = () => makePosition(10_000_000_000n),
    slot0Error = false,
  } = overrides

  readContractMock.mockImplementation(async ({ functionName, args }: Call) => {
    switch (functionName) {
      case 'slot0':
        if (slot0Error) throw new Error('rpc down')
        return [Q96, 0, 0, 0, 0, true]
      case 'gauge':
        return GAUGE
      case 'nft':
        return NFPM
      case 'stakedValues':
        return stakedIds
      case 'ownerOf': {
        const name = ownerOf(args?.[0] as bigint)
        if (name === 'REVERT') throw new Error('nonexistent token')
        return name
      }
      case 'positions':
        return positions(args?.[0] as bigint)
      default:
        throw new Error(`unexpected call: ${functionName}`)
    }
  })
}

describe('getWrappedSlipstreamTokenAmounts', () => {
  beforeEach(() => readContractMock.mockReset())

  const config = { pool: POOL, wrapper: WRAPPER }

  it('returns amounts for both tokens of an in-range position the owner holds', async () => {
    installHandlers({})
    const amounts = await getWrappedSlipstreamTokenAmounts(8453, OWNER, config)
    const byToken = new Map(amounts.map((a) => [a.tokenAddress.toLowerCase(), a.amount]))
    expect(byToken.size).toBe(2)
    expect(byToken.get(TOKEN0)! > 0n).toBe(true)
    expect(byToken.get(TOKEN1)! > 0n).toBe(true)
  })

  it('only counts token ids owned by the requested owner', async () => {
    installHandlers({ stakedIds: [1n, 2n] })
    const single = await getWrappedSlipstreamTokenAmounts(8453, OWNER, config)

    installHandlers({ stakedIds: [1n, 2n], ownerOf: () => OWNER })
    const double = await getWrappedSlipstreamTokenAmounts(8453, OWNER, config)

    const singleT0 = single.find((a) => a.tokenAddress.toLowerCase() === TOKEN0)!.amount
    const doubleT0 = double.find((a) => a.tokenAddress.toLowerCase() === TOKEN0)!.amount
    expect(doubleT0).toBe(singleT0 * 2n)
  })

  it('skips ids whose ownerOf reverts and positions with zero liquidity', async () => {
    installHandlers({
      stakedIds: [1n, 2n, 3n],
      ownerOf: (id) => (id === 3n ? 'REVERT' : OWNER),
      positions: (id) => makePosition(id === 2n ? 0n : 10_000_000_000n),
    })
    const single = await getWrappedSlipstreamTokenAmounts(8453, OWNER, config)
    // id 2 has zero liquidity, id 3 reverts -> only id 1 contributes
    installHandlers({ stakedIds: [1n] })
    const reference = await getWrappedSlipstreamTokenAmounts(8453, OWNER, config)
    expect(single).toEqual(reference)
  })

  it('returns [] when the wrapper has no staked ids', async () => {
    installHandlers({ stakedIds: [] })
    await expect(getWrappedSlipstreamTokenAmounts(8453, OWNER, config)).resolves.toEqual([])
  })

  it('returns [] instead of throwing when a read fails', async () => {
    installHandlers({ slot0Error: true })
    await expect(getWrappedSlipstreamTokenAmounts(8453, OWNER, config)).resolves.toEqual([])
  })
})
