import { DEFAULT_RUN_OPTIONS, createExecutorForChain } from './executor'

describe('executor', () => {
  it('DEFAULT_RUN_OPTIONS spreads Presets.throughput', () => {
    expect(DEFAULT_RUN_OPTIONS).toEqual({
      maxConcurrentBatches: 5,
      adaptiveBatching: true,
      dedupe: true,
    })
  })

  it('throws for an unsupported chainId', () => {
    expect(() => createExecutorForChain('999999')).toThrow(/999999/)
  })

  it('returns a StepExecutor for a supported chain', () => {
    const executor = createExecutorForChain('8453')
    expect(typeof executor.executeMulticall).toBe('function')
    expect(typeof executor.getBlockNumber).toBe('function')
  })
})
