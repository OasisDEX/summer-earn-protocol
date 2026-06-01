import { Options } from '@layerzerolabs/lz-v2-utilities'

import { constructLzOptions } from '@/utils/layerzero-options'

// Compute the canonical encoding via @layerzerolabs/lz-v2-utilities directly,
// then assert constructLzOptions matches. This protects against accidentally
// switching to a different option type / worker / format while keeping the
// test independent of hand-counted hex padding.
const canonicalLzOptions = (gas: bigint): string =>
  `0x${Buffer.from(
    Options.newOptions().addExecutorLzReceiveOption(Number(gas), 0).toBytes(),
  ).toString('hex')}`.toLowerCase()

describe('constructLzOptions', () => {
  it('encodes the default gas limit (200000) when called without arguments', () => {
    expect(constructLzOptions().toLowerCase()).toBe(canonicalLzOptions(200000n))
  })

  it('encodes the supplied gas limit (500000)', () => {
    expect(constructLzOptions(500000n).toLowerCase()).toBe(canonicalLzOptions(500000n))
  })

  it('matches the canonical OptionsBuilder output for several gas amounts', () => {
    for (const gas of [1n, 100000n, 750000n, 5_000_000n]) {
      expect(constructLzOptions(gas).toLowerCase()).toBe(canonicalLzOptions(gas))
    }
  })

  it('returns a 0x-prefixed hex string of the expected length (22 bytes = 44 hex chars)', () => {
    const bytes = constructLzOptions(123456n)
    expect(bytes).toMatch(/^0x[0-9a-fA-F]+$/)
    expect(bytes.length).toBe(2 + 44)
  })

  it('produces the lzReceive option type byte (0x01), not lzCompose (0x03)', () => {
    const bytes = constructLzOptions(500000n).toLowerCase()
    // structure: 0x | 0003 (type3 prefix) | 01 (worker) | 0011 (len) | XX (optionType) | gas[16B]
    // optionType byte starts at character index 2 + 4 + 2 + 4 = 12
    expect(bytes.slice(12, 14)).toBe('01')
  })

  it('encodes the option length field as 17 (0x0011)', () => {
    const bytes = constructLzOptions(500000n).toLowerCase()
    // length field at characters 2 + 4 + 2 = 8 .. 12
    expect(bytes.slice(8, 12)).toBe('0011')
  })

  it('uses executor worker id 0x01', () => {
    const bytes = constructLzOptions(500000n).toLowerCase()
    // worker byte at characters 2 + 4 = 6 .. 8
    expect(bytes.slice(6, 8)).toBe('01')
  })

  it('starts with the TYPE_3 prefix 0x0003', () => {
    expect(constructLzOptions(500000n).toLowerCase().slice(0, 6)).toBe('0x0003')
  })
})
