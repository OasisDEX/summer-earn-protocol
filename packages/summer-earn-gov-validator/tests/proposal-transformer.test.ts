import {
  CrossChainProposal,
  Proposal,
  ProposalWithCrossChain,
  SubgraphProposalStatus,
} from '@/types/governance'
import { transformProposal } from '@/utils/proposal-transformer'

const baseProposal = (overrides: Partial<Proposal> = {}): Proposal => ({
  id: '1',
  governor: '0xgovernor',
  targets: ['0xtarget'],
  values: ['0'],
  calldatas: ['0x'],
  description: '# SIP-9: Test\n\nBody.',
  descriptionHash: '0x' + 'a'.repeat(64),
  status: 'Pending' as SubgraphProposalStatus,
  chains: ['8453'],
  eta: '0',
  createdAt: '1000000',
  quorum: (100n * 10n ** 18n).toString(),
  forVotes: '0',
  againstVotes: '0',
  abstainVotes: '0',
  votes: [],
  voteStart: '1000100',
  voteEnd: '1000200',
  salt: '0x',
  ...overrides,
})

const withCross = (
  proposal: Proposal,
  crossChainProposals: CrossChainProposal[] = [],
): ProposalWithCrossChain => ({ baseProposal: proposal, crossChainProposals })

describe('transformProposal - status passthrough and overrides', () => {
  it('keeps Executed when there are no cross-chain proposals', () => {
    const result = transformProposal(
      withCross(baseProposal({ status: 'Executed' as SubgraphProposalStatus })),
      1_000_300,
    )
    expect(result.status).toBe('Executed')
  })

  it('promotes Executed -> Executed on Hub when any cross-chain leg is not executed', () => {
    const ccp: CrossChainProposal = {
      id: 'cc-1',
      proposalId: '1',
      chainId: '42161',
      status: 'Queued',
      salt: '0x',
      targets: [],
      values: [],
      calldatas: [],
      eta: '0',
    }
    const result = transformProposal(
      withCross(baseProposal({ status: 'Executed' as SubgraphProposalStatus }), [ccp]),
      1_000_300,
    )
    expect(result.status).toBe('Executed on Hub')
  })

  it('keeps Executed when every cross-chain leg has also been executed', () => {
    const ccp: CrossChainProposal = {
      id: 'cc-1',
      proposalId: '1',
      chainId: '42161',
      status: 'Executed',
      salt: '0x',
      targets: [],
      values: [],
      calldatas: [],
      eta: '0',
    }
    const result = transformProposal(
      withCross(baseProposal({ status: 'Executed' as SubgraphProposalStatus }), [ccp]),
      1_000_300,
    )
    expect(result.status).toBe('Executed')
  })

  it('derives Active when now is inside [voteStart, voteEnd]', () => {
    const result = transformProposal(withCross(baseProposal()), 1_000_150)
    expect(result.status).toBe('Active')
  })

  it('derives Defeated when past voteEnd, quorum reached, against >= for', () => {
    const result = transformProposal(
      withCross(
        baseProposal({
          forVotes: (10n * 10n ** 18n).toString(),
          againstVotes: (200n * 10n ** 18n).toString(),
        }),
      ),
      1_000_250,
    )
    expect(result.status).toBe('Defeated')
  })

  it('derives Defeated when past voteEnd and quorum not reached', () => {
    const result = transformProposal(
      withCross(
        baseProposal({
          forVotes: (5n * 10n ** 18n).toString(),
          againstVotes: '0',
        }),
      ),
      1_000_250,
    )
    expect(result.status).toBe('Defeated')
  })

  it('derives Succeeded when past voteEnd, not defeated, not already Queued', () => {
    const result = transformProposal(
      withCross(
        baseProposal({
          forVotes: (200n * 10n ** 18n).toString(),
          againstVotes: '0',
        }),
      ),
      1_000_250,
    )
    expect(result.status).toBe('Succeeded')
  })

  it('leaves Canceled untouched', () => {
    const result = transformProposal(
      withCross(baseProposal({ status: 'Canceled' as SubgraphProposalStatus })),
      1_000_300,
    )
    expect(result.status).toBe('Canceled')
  })
})

describe('transformProposal - derived numeric fields', () => {
  it('returns zero vote percentages when there are no votes', () => {
    const result = transformProposal(withCross(baseProposal()), 1_000_050)
    expect(result.forPercent).toBe(0)
    expect(result.againstPercent).toBe(0)
    expect(result.abstainPercent).toBe(0)
  })

  it('converts wei-string vote counts to human numbers via /1e18', () => {
    const result = transformProposal(
      withCross(
        baseProposal({
          forVotes: (50n * 10n ** 18n).toString(),
          againstVotes: (25n * 10n ** 18n).toString(),
          abstainVotes: (25n * 10n ** 18n).toString(),
        }),
      ),
      1_000_150,
    )
    expect(result.forVotes).toBe(50)
    expect(result.againstVotes).toBe(25)
    expect(result.abstainVotes).toBe(25)
    expect(result.forPercent).toBe(50)
    expect(result.againstPercent).toBe(25)
    expect(result.abstainPercent).toBe(25)
  })

  it('computes timeRemaining as voteEnd - now when voting is open', () => {
    const result = transformProposal(withCross(baseProposal()), 1_000_150)
    expect(result.timeRemaining).toBe(50)
  })

  it('computes timeRemaining as voteStart - now when voting has not started', () => {
    const result = transformProposal(withCross(baseProposal()), 1_000_050)
    expect(result.timeRemaining).toBe(50)
  })

  it('joins multiple chain names into the chain field', () => {
    const result = transformProposal(withCross(baseProposal({ chains: ['42161'] })), 1_000_300)
    expect(result.chain).toContain('Arbitrum')
    expect(result.chain).toContain('Base')
  })

  it('uses the live wall clock as the default now (not a leaked 0/index)', () => {
    // baseProposal's voteEnd is 1000200 (~Jan 1970). With the real wall clock
    // (now >> voteEnd) the proposal is past voting with no votes -> Defeated,
    // and timeRemaining = voteEnd - now is strongly negative. If `now` had
    // defaulted to 0 (or a leaked index), now < voteStart, timeRemaining would
    // be +1000100 and status would stay Pending. So these assertions prove the
    // default is the live clock.
    const result = transformProposal(withCross(baseProposal()))
    expect(result.status).toBe('Defeated')
    expect(result.timeRemaining).toBeLessThan(0)
  })

  it('falls back to empty string when description is undefined', () => {
    const proposal = baseProposal({ description: undefined as unknown as string })
    const result = transformProposal(withCross(proposal), 1_000_050)
    expect(result.title).toBe('Untitled Proposal')
  })

  it('falls back to empty arrays when targets/values/calldatas are undefined', () => {
    const proposal = baseProposal({
      targets: undefined as unknown as string[],
      values: undefined as unknown as string[],
      calldatas: undefined as unknown as string[],
    })
    const result = transformProposal(withCross(proposal), 1_000_050)
    expect(result.targets).toEqual([])
    expect(result.values).toEqual([])
    expect(result.calldatas).toEqual([])
  })
})
