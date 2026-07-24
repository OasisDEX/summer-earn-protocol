import { defineTask, runSettled } from '@halaprix/domino'

import { callKey, FAIL, MockStepExecutor } from './mock-executor'

const TOKEN = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' as const
const erc20Abi = [
  {
    type: 'function',
    name: 'decimals',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const

describe('MockStepExecutor', () => {
  it('resolves a defineTask graph from the handler map', async () => {
    const executor = new MockStepExecutor({
      [callKey(TOKEN, 'decimals')]: 6,
      [callKey(TOKEN, 'balanceOf')]: (args) => (args?.[0] === '0x01' ? 42n : 0n),
    })
    const task = defineTask((t) => ({
      decimals: t.call({ target: TOKEN, abi: erc20Abi, functionName: 'decimals' }),
      balance: t.call({
        target: TOKEN,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: ['0x01' as `0x${string}`],
      }),
    }))
    const [result] = await runSettled(executor, [task])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') {
      expect(result.value).toEqual({ decimals: 6, balance: 42n })
    }
  })

  it('fails calls mapped to FAIL and calls with no handler', async () => {
    const executor = new MockStepExecutor({ [callKey(TOKEN, 'decimals')]: FAIL })
    const task = defineTask((t) => ({
      decimals: t.call({ target: TOKEN, abi: erc20Abi, functionName: 'decimals', optional: true }),
      balance: t.call({
        target: TOKEN,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: ['0x01' as `0x${string}`],
        optional: true,
      }),
    }))
    const [result] = await runSettled(executor, [task])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') {
      expect(result.value).toEqual({ decimals: undefined, balance: undefined })
    }
  })

  it('records dispatched batches for round-trip assertions', async () => {
    const executor = new MockStepExecutor({ [callKey(TOKEN, 'decimals')]: 6 })
    const task = defineTask((t) => ({
      decimals: t.call({ target: TOKEN, abi: erc20Abi, functionName: 'decimals' }),
    }))
    await runSettled(executor, [task])
    expect(executor.batches).toHaveLength(1)
    expect(executor.batches[0][0].functionName).toBe('decimals')
  })
})
