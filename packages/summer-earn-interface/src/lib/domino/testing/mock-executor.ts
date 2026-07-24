import type { RawResult, StepCall, StepExecutor } from '@halaprix/domino'

/** Sentinel: map a call key to FAIL to make that call return a failure result. */
export const FAIL = Symbol('domino-mock-fail')

/** Static value, FAIL, or an args-dependent resolver. */
export type MockValue = unknown | ((args: readonly unknown[] | undefined) => unknown)

export function callKey(target: string, functionName: string): string {
  return `${target.toLowerCase()}.${functionName}`
}

/**
 * In-memory StepExecutor for tests. Calls resolve from the handler map by
 * `callKey(target, functionName)`; unmapped calls fail (so a test that
 * forgets a handler surfaces as a visible failure, not a hang).
 */
export class MockStepExecutor implements StepExecutor {
  readonly batches: StepCall[][] = []

  constructor(private readonly handlers: Record<string, MockValue>) {}

  async executeMulticall(calls: StepCall[]): Promise<RawResult[]> {
    this.batches.push(calls)
    return calls.map((call) => {
      const key = callKey(call.target, call.functionName)
      if (!(key in this.handlers)) {
        return { status: 'failure', error: new Error(`MockStepExecutor: no handler for ${key}`) }
      }
      const handler = this.handlers[key]
      const value =
        typeof handler === 'function'
          ? (handler as (args: readonly unknown[] | undefined) => unknown)(call.args)
          : handler
      if (value === FAIL) {
        return {
          status: 'failure',
          error: new Error(`MockStepExecutor: mocked failure for ${key}`),
        }
      }
      return { status: 'success', value }
    })
  }

  async getBlockNumber(): Promise<bigint> {
    return 1n
  }
}
