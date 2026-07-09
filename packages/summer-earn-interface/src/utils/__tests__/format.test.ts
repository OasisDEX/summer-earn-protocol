import { formatAddress, formatHash } from '../address'
import { formatCompact, formatNumber, formatPercent } from '../format'

describe('formatAddress', () => {
  const addr = '0x194f360D130F2393a5E9F3117A6a1B78aBEa1624'

  it('shortens with default 4 chars and U+2026 ellipsis', () => {
    expect(formatAddress(addr)).toBe('0x194f…1624')
  })

  it('respects a custom char count', () => {
    expect(formatAddress(addr, 6)).toBe('0x194f36…Ea1624')
  })

  it('returns an em dash for null/undefined/empty', () => {
    expect(formatAddress(null)).toBe('—')
    expect(formatAddress(undefined)).toBe('—')
    expect(formatAddress('')).toBe('—')
  })

  it('leaves short strings untouched', () => {
    expect(formatAddress('0x1234')).toBe('0x1234')
  })
})

describe('formatHash', () => {
  it('defaults to 6 chars per side', () => {
    const hash = '0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789'
    expect(formatHash(hash)).toBe('0xabcdef…456789')
  })
})

describe('formatNumber', () => {
  it('defaults to max 2 fraction digits with grouping', () => {
    expect(formatNumber(1234567.891)).toBe('1,234,567.89')
  })

  it('does not pad by default', () => {
    expect(formatNumber(5)).toBe('5')
  })

  it('pins digits when min=max (toFixed replacement)', () => {
    expect(formatNumber(5, { min: 2, max: 2 })).toBe('5.00')
    expect(formatNumber(1.005, { min: 6, max: 6 })).toBe('1.005000')
  })

  it('accepts numeric strings', () => {
    expect(formatNumber('42.5')).toBe('42.5')
  })

  it('returns an em dash for non-finite input', () => {
    expect(formatNumber(NaN)).toBe('—')
    expect(formatNumber(Infinity)).toBe('—')
  })
})

describe('formatPercent', () => {
  it('formats already-scaled percentages', () => {
    expect(formatPercent(12.345)).toBe('12.35%')
    expect(formatPercent(0)).toBe('0%')
  })

  it('respects maxDecimals', () => {
    expect(formatPercent(12.345, 1)).toBe('12.3%')
    expect(formatPercent(99.5, 0)).toBe('100%')
  })
})

describe('formatCompact', () => {
  it('applies K/M/B suffixes', () => {
    expect(formatCompact(1234)).toBe('1.23K')
    expect(formatCompact(1234567)).toBe('1.23M')
    expect(formatCompact(1234567890)).toBe('1.23B')
  })

  it('keeps small numbers plain', () => {
    expect(formatCompact(999.4)).toBe('999.4')
  })

  it('handles negatives', () => {
    expect(formatCompact(-2500)).toBe('-2.50K')
  })
})
