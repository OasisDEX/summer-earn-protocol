import { encodeFunctionData } from 'viem'

import { ProposalAction } from '@/types/governance'
import {
  bigIntSafeReplacer,
  buildActionCalldata,
  computeGasRatio,
  computeGasSeverity,
  DEFAULT_LZ_GAS_LIMIT,
  GAS_SEVERITY_ORDER,
  GasSeverityOrIdle,
  LZ_GAS_CRITICAL_THRESHOLD,
  LZ_GAS_HEADROOM_PERCENT,
  LZ_GAS_WARNING_THRESHOLD,
  parseLzGas,
  partitionSimChains,
  worstSeverity,
  ZERO_BYTES32,
} from '@/utils/proposal-encoding'

const makeAction = (overrides: Partial<ProposalAction> = {}): ProposalAction => ({
  id: 'test',
  chainId: '8453',
  target: '0x0000000000000000000000000000000000000001',
  abi: [],
  method: '',
  args: {},
  isValid: false,
  ...overrides,
})

describe('module constants', () => {
  it('exposes a 500000 default gas string', () => {
    expect(DEFAULT_LZ_GAS_LIMIT).toBe('500000')
  })

  it('orders severity strictly: idle < ok < warning < critical', () => {
    expect(GAS_SEVERITY_ORDER.idle).toBeLessThan(GAS_SEVERITY_ORDER.ok)
    expect(GAS_SEVERITY_ORDER.ok).toBeLessThan(GAS_SEVERITY_ORDER.warning)
    expect(GAS_SEVERITY_ORDER.warning).toBeLessThan(GAS_SEVERITY_ORDER.critical)
  })

  it('keeps thresholds and headroom percent in sync', () => {
    expect(LZ_GAS_WARNING_THRESHOLD).toBeLessThan(LZ_GAS_CRITICAL_THRESHOLD)
    expect(LZ_GAS_HEADROOM_PERCENT).toBe(Math.round((1 - LZ_GAS_WARNING_THRESHOLD) * 100))
  })

  it('uses the canonical 32-byte zero salt', () => {
    expect(ZERO_BYTES32).toBe(`0x${'0'.repeat(64)}`)
  })
})

describe('bigIntSafeReplacer', () => {
  it('serializes bigints to decimal strings inside JSON.stringify', () => {
    const json = JSON.stringify({ n: 123n }, bigIntSafeReplacer)
    expect(json).toBe('{"n":"123"}')
  })

  it('leaves non-bigint values untouched', () => {
    expect(bigIntSafeReplacer('k', 42)).toBe(42)
    expect(bigIntSafeReplacer('k', 'hello')).toBe('hello')
    expect(bigIntSafeReplacer('k', null)).toBeNull()
    expect(bigIntSafeReplacer('k', { a: 1 })).toEqual({ a: 1 })
  })

  it('lets JSON.stringify round-trip a typical action shape with bigints', () => {
    const shape = { values: [0n, 1000000000000000000n], description: 'hello' }
    expect(() => JSON.stringify(shape, bigIntSafeReplacer)).not.toThrow()
    expect(JSON.stringify(shape, bigIntSafeReplacer)).toBe(
      '{"values":["0","1000000000000000000"],"description":"hello"}',
    )
  })
})

describe('parseLzGas', () => {
  it('returns the default when input is undefined', () => {
    expect(parseLzGas(undefined)).toBe(BigInt(DEFAULT_LZ_GAS_LIMIT))
  })

  it('returns the default when input is an empty string', () => {
    expect(parseLzGas('')).toBe(BigInt(DEFAULT_LZ_GAS_LIMIT))
  })

  it('parses a plain decimal string', () => {
    expect(parseLzGas('250000')).toBe(250000n)
  })

  it('strips underscores, commas, and whitespace before parsing', () => {
    expect(parseLzGas('1_000_000')).toBe(1000000n)
    expect(parseLzGas('1,000,000')).toBe(1000000n)
    expect(parseLzGas('  500 000  ')).toBe(500000n)
  })

  it('falls back to the default when input has non-digit characters', () => {
    expect(parseLzGas('500k')).toBe(BigInt(DEFAULT_LZ_GAS_LIMIT))
    expect(parseLzGas('0x1234')).toBe(BigInt(DEFAULT_LZ_GAS_LIMIT))
    expect(parseLzGas('-100')).toBe(BigInt(DEFAULT_LZ_GAS_LIMIT))
    expect(parseLzGas('1.5')).toBe(BigInt(DEFAULT_LZ_GAS_LIMIT))
  })

  it('accepts zero as a valid value (caller decides what to do)', () => {
    expect(parseLzGas('0')).toBe(0n)
  })

  it('handles very large values without precision loss', () => {
    const huge = '99999999999999999999999999'
    expect(parseLzGas(huge)).toBe(BigInt(huge))
  })
})

describe('buildActionCalldata', () => {
  const transferAbi = [
    {
      name: 'transfer',
      type: 'function',
      inputs: [
        { name: 'to', type: 'address' },
        { name: 'amount', type: 'uint256' },
      ],
      outputs: [{ name: '', type: 'bool' }],
      stateMutability: 'nonpayable',
    },
  ]

  const pauseAbi = [
    {
      name: 'pause',
      type: 'function',
      inputs: [],
      outputs: [],
      stateMutability: 'nonpayable',
    },
  ]

  it('returns rawCalldata verbatim when provided, ignoring abi/method/args', () => {
    const action = makeAction({
      rawCalldata: '0xdeadbeef',
      abi: transferAbi,
      method: 'transfer',
    })
    expect(buildActionCalldata(action)).toBe('0xdeadbeef')
  })

  it('returns 0x when no matching method is found in the abi', () => {
    expect(buildActionCalldata(makeAction({ abi: [], method: 'foo' }))).toBe('0x')
    expect(buildActionCalldata(makeAction({ abi: transferAbi, method: 'doesNotExist' }))).toBe('0x')
  })

  it('encodes a function call with arguments mapped from action.args', () => {
    const action = makeAction({
      abi: transferAbi,
      method: 'transfer',
      args: {
        to: '0x0000000000000000000000000000000000000001',
        amount: 1000n,
      },
    })
    const expected = encodeFunctionData({
      abi: transferAbi,
      functionName: 'transfer',
      args: ['0x0000000000000000000000000000000000000001', 1000n],
    })
    expect(buildActionCalldata(action)).toBe(expected)
  })

  it('encodes a no-arg function as just the 4-byte selector', () => {
    const action = makeAction({ abi: pauseAbi, method: 'pause' })
    const data = buildActionCalldata(action)
    // selector only -> 4 bytes -> 0x + 8 hex chars
    expect(data).toMatch(/^0x[0-9a-fA-F]{8}$/)
  })

  it('emits selector-only calldata when inputs is undefined (malformed abi)', () => {
    // Method exists but inputs missing. Returning 0x would hit the contract
    // fallback; we should still emit the selector so the intended function
    // is dispatched.
    const malformedAbi = [
      {
        name: 'doStuff',
        type: 'function',
        outputs: [],
        stateMutability: 'nonpayable',
      },
    ]
    const action = makeAction({ abi: malformedAbi, method: 'doStuff' })
    const data = buildActionCalldata(action)
    expect(data).toMatch(/^0x[0-9a-fA-F]{8}$/)
    expect(data).not.toBe('0x')
  })

  it('prefers rawCalldata over a valid abi-based encoding (deterministic precedence)', () => {
    const action = makeAction({
      rawCalldata: '0xbadc0de0',
      abi: transferAbi,
      method: 'transfer',
      args: { to: '0x0000000000000000000000000000000000000001', amount: 1n },
    })
    expect(buildActionCalldata(action)).toBe('0xbadc0de0')
  })
})

describe('computeGasSeverity / computeGasRatio', () => {
  it('returns ok well below the warning threshold', () => {
    expect(computeGasSeverity(100_000, 500_000n)).toBe('ok')
  })

  it('returns warning at the warning threshold exactly', () => {
    const gas = Math.round(500_000 * LZ_GAS_WARNING_THRESHOLD)
    expect(computeGasSeverity(gas, 500_000n)).toBe('warning')
  })

  it('returns warning just below the critical threshold', () => {
    expect(computeGasSeverity(499_999, 500_000n)).toBe('warning')
  })

  it('returns critical at the critical threshold exactly (gasUsed == encoded)', () => {
    expect(computeGasSeverity(500_000, 500_000n)).toBe('critical')
  })

  it('returns critical when gasUsed exceeds encoded', () => {
    expect(computeGasSeverity(600_000, 500_000n)).toBe('critical')
  })

  it('treats encodedGas == 0 as infinite ratio (critical)', () => {
    expect(computeGasSeverity(1, 0n)).toBe('critical')
    expect(computeGasRatio(1, 0n)).toBe(Number.POSITIVE_INFINITY)
  })

  it('computes a clean ratio for normal values', () => {
    expect(computeGasRatio(250_000, 500_000n)).toBeCloseTo(0.5)
  })
})

describe('worstSeverity', () => {
  it('returns idle for an empty list', () => {
    expect(worstSeverity([])).toBe('idle')
  })

  it('returns the highest-severity entry', () => {
    const cases: Array<[GasSeverityOrIdle[], GasSeverityOrIdle]> = [
      [['idle'], 'idle'],
      [['ok'], 'ok'],
      [['ok', 'warning'], 'warning'],
      [['ok', 'warning', 'critical'], 'critical'],
      [['critical', 'ok'], 'critical'],
      [['idle', 'idle', 'idle'], 'idle'],
      [['idle', 'ok'], 'ok'],
    ]
    for (const [input, expected] of cases) {
      expect(worstSeverity(input)).toBe(expected)
    }
  })

  it('is order-invariant', () => {
    expect(worstSeverity(['critical', 'ok', 'warning'])).toBe('critical')
    expect(worstSeverity(['ok', 'critical', 'warning'])).toBe('critical')
    expect(worstSeverity(['warning', 'ok', 'critical'])).toBe('critical')
  })
})

describe('partitionSimChains', () => {
  // Tenderly-supported chains (e.g. Base, Arbitrum) vs. unsupported ones
  // (e.g. HyperLiquid / chainId 999). The submit gate requires success only
  // for `required`; `unsimulatable` drives the "no Tenderly trace" warning.
  const isSimulatable = (id: string) => id !== '999'

  it('splits expected chains into Tenderly-simulatable and unsimulatable', () => {
    expect(partitionSimChains(['8453', '999'], isSimulatable)).toEqual({
      required: ['8453'],
      unsimulatable: ['999'],
    })
  })

  it('returns two empty arrays for no expected chains', () => {
    expect(partitionSimChains([], isSimulatable)).toEqual({
      required: [],
      unsimulatable: [],
    })
  })

  it('puts every chain in required when all are simulatable', () => {
    expect(partitionSimChains(['8453', '42161', '146'], isSimulatable)).toEqual({
      required: ['8453', '42161', '146'],
      unsimulatable: [],
    })
  })

  it('puts every chain in unsimulatable when none are simulatable', () => {
    expect(partitionSimChains(['999'], () => false)).toEqual({
      required: [],
      unsimulatable: ['999'],
    })
  })

  it('preserves input order within each partition', () => {
    expect(partitionSimChains(['8453', '999', '42161', '999'], isSimulatable)).toEqual({
      required: ['8453', '42161'],
      unsimulatable: ['999', '999'],
    })
  })
})
