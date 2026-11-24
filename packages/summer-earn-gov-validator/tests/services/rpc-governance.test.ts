import { encodeAbiParameters, encodeEventTopics } from 'viem'

import {
  buildProposalsFromLogs,
  buildVotesFromLogs,
  decodeGovernorLog,
  findBlockAtOrAfter,
  getLogsSplitting,
  GOVERNOR_EVENTS_ABI,
  type GovernorLog,
  HUB_GOVERNOR,
  mapGovernorState,
  scanLogs,
  V1_GOVERNOR,
} from '@/services/rpc-governance'

const log = (
  eventName: string,
  args: Record<string, unknown>,
  extra: Partial<GovernorLog> = {},
): GovernorLog => ({
  address: HUB_GOVERNOR,
  eventName,
  args,
  blockNumber: 100n,
  transactionHash: '0xaaa',
  logIndex: 0,
  ...extra,
})

describe('mapGovernorState', () => {
  it('maps OZ states to subgraph statuses', () => {
    expect([0, 1, 2, 3, 4, 5, 6, 7].map(mapGovernorState)).toEqual([
      'Pending',
      'Pending',
      'Canceled',
      'Pending',
      'Pending',
      'Queued',
      'Pending',
      'Executed',
    ])
  })
})

describe('findBlockAtOrAfter', () => {
  it('finds the first block at/after a timestamp with a non-constant block time', async () => {
    // 2s blocks up to block 1000, then 0.2s blocks (5 per second).
    const ts = (n: bigint) => (n <= 1000n ? n * 2n : 2000n + (n - 1000n) / 5n)
    expect(await findBlockAtOrAfter(async (n) => ts(n), 1000n, 50_000n)).toBe(500n)
    expect(await findBlockAtOrAfter(async (n) => ts(n), 2100n, 50_000n)).toBe(1500n)
    expect(await findBlockAtOrAfter(async (n) => ts(n), 0n, 50_000n)).toBe(0n)
  })
})

describe('getLogsSplitting / scanLogs', () => {
  it('splits ranges the provider rejects and keeps every log', async () => {
    // Provider that only accepts spans of <= 1000 blocks; one log per accepted call.
    const fetcher = async (from: bigint, to: bigint) => {
      if (to - from + 1n > 1000n) throw new Error('range too large')
      return [log('ProposalExecuted', { proposalId: from })]
    }
    const logs = await getLogsSplitting(fetcher, 0n, 3999n)
    expect(logs.map((l) => l.args.proposalId)).toEqual([0n, 1000n, 2000n, 3000n])
  })

  it('propagates errors once the span cannot be split further', async () => {
    const fetcher = async () => {
      throw new Error('rpc down')
    }
    await expect(getLogsSplitting(fetcher, 0n, 400n)).rejects.toThrow('rpc down')
  })

  it('stops once the call budget is spent instead of returning partial data', async () => {
    const fetcher = async (from: bigint, to: bigint) => {
      if (to - from + 1n > 1000n) throw new Error('range too large')
      return []
    }
    await expect(getLogsSplitting(fetcher, 0n, 7999n, { remaining: 3 })).rejects.toThrow()
  })

  it('chunks the window in order and covers it exactly', async () => {
    const seen: Array<[bigint, bigint]> = []
    const fetcher = async (from: bigint, to: bigint) => {
      seen.push([from, to])
      return [log('ProposalExecuted', { proposalId: from })]
    }
    const logs = await scanLogs(fetcher, 10n, 34n, 10n)
    expect(logs.map((l) => l.args.proposalId)).toEqual([10n, 20n, 30n])
    expect(seen.sort((a, b) => Number(a[0] - b[0]))).toEqual([
      [10n, 19n],
      [20n, 29n],
      [30n, 34n],
    ])
  })
})

describe('decodeGovernorLog', () => {
  it('decodes a governor event and ignores unknown ones', () => {
    const topics = encodeEventTopics({
      abi: GOVERNOR_EVENTS_ABI,
      eventName: 'ProposalSentCrossChain',
      args: { proposalId: 5n, dstEid: 30110 },
    })
    const decoded = decodeGovernorLog({
      address: '0x4cEeE1b6289624d381383C1Bb42B118d5f2c3274',
      topics: topics as `0x${string}`[],
      data: '0x',
      blockNumber: 7n,
      logIndex: 2,
      transactionHash: '0xABC',
      timestamp: 99n,
    })
    expect(decoded).toMatchObject({
      address: HUB_GOVERNOR,
      eventName: 'ProposalSentCrossChain',
      transactionHash: '0xabc',
      timestamp: 99n,
      args: { proposalId: 5n, dstEid: 30110 },
    })

    const unknown = decodeGovernorLog({
      address: HUB_GOVERNOR,
      topics: [`0x${'11'.repeat(32)}`],
      data: encodeAbiParameters([{ type: 'uint256' }], [1n]),
      blockNumber: 1n,
      logIndex: 0,
      transactionHash: '0x1',
    })
    expect(unknown).toBeNull()
  })
})

describe('buildProposalsFromLogs', () => {
  const created = (id: bigint, blockNumber: bigint, address: string = HUB_GOVERNOR) =>
    log(
      'ProposalCreated',
      {
        proposalId: id,
        proposer: '0x0000000000000000000000000000000000000001',
        targets: ['0xABCDEF0000000000000000000000000000000001'],
        values: [0n],
        signatures: [''],
        calldatas: ['0x1234'],
        voteStart: 10n,
        voteEnd: 20n,
        description: 'hello',
      },
      { blockNumber, address },
    )

  it('builds subgraph-shaped proposals for one governor, newest first', () => {
    const out = buildProposalsFromLogs(
      [created(1n, 5n), created(2n, 9n), created(3n, 7n, V1_GOVERNOR)],
      HUB_GOVERNOR,
    )
    expect(out.map((p) => p.proposal.id)).toEqual(['2', '1'])
    const p = out[1].proposal
    expect(p.governor).toBe(HUB_GOVERNOR)
    expect(p.targets).toEqual(['0xabcdef0000000000000000000000000000000001'])
    expect(p.values).toEqual(['0'])
    expect(p.chains).toEqual([])
    expect(p.dstIds).toEqual([])
    expect(p.salt).toBe('0x')
    // keccak256("hello")
    expect(p.descriptionHash).toBe(
      '0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8',
    )
    expect(buildProposalsFromLogs([created(3n, 7n, V1_GOVERNOR)], V1_GOVERNOR)).toHaveLength(1)
  })

  it('joins ProposalSentCrossChain to the hub proposal executed in the same tx', () => {
    const out = buildProposalsFromLogs(
      [
        created(1n, 5n),
        log('ProposalExecuted', { proposalId: 1n }, { transactionHash: '0xexec' }),
        log(
          'ProposalSentCrossChain',
          { proposalId: 77n, dstEid: 30110 },
          { transactionHash: '0xexec' },
        ),
        // Unknown eid and unrelated tx are ignored.
        log(
          'ProposalSentCrossChain',
          { proposalId: 78n, dstEid: 1 },
          { transactionHash: '0xexec' },
        ),
        log(
          'ProposalSentCrossChain',
          { proposalId: 79n, dstEid: 30101 },
          { transactionHash: '0xother' },
        ),
      ],
      HUB_GOVERNOR,
    )
    expect(out[0].proposal.chains).toEqual(['42161'])
    expect(out[0].proposal.dstIds).toEqual(['77'])
  })
})

describe('buildVotesFromLogs', () => {
  const vote = (id: bigint, weight: bigint, blockNumber: bigint, logIndex: number, ts?: bigint) =>
    log(
      'VoteCast',
      {
        voter: '0xAAAA000000000000000000000000000000000001',
        proposalId: id,
        support: 1,
        weight,
        reason: 'r',
      },
      { blockNumber, logIndex, timestamp: ts },
    )

  it('keeps non-zero votes for the proposal, newest first', () => {
    const votes = buildVotesFromLogs(
      [
        vote(1n, 5n, 100n, 1, 1000n),
        vote(1n, 0n, 101n, 2),
        vote(2n, 5n, 102n, 3),
        vote(1n, 7n, 103n, 4),
      ],
      '1',
    )
    expect(votes).toEqual([
      {
        id: '0xaaa-4',
        voter: '0xaaaa000000000000000000000000000000000001',
        support: 1,
        votes: '7',
        reason: 'r',
        // No timestamp from the source yet: resolved later from the block.
        timestamp: 'block:103',
      },
      {
        id: '0xaaa-1',
        voter: '0xaaaa000000000000000000000000000000000001',
        support: 1,
        votes: '5',
        reason: 'r',
        timestamp: '1000',
      },
    ])
  })

  it('caps at the 100 newest votes', () => {
    const many = Array.from({ length: 150 }, (_, i) => vote(1n, 1n, BigInt(i), 0, BigInt(i)))
    const votes = buildVotesFromLogs(many, '1')
    expect(votes).toHaveLength(100)
    expect(votes[0].timestamp).toBe('149')
    expect(votes[99].timestamp).toBe('50')
  })
})
