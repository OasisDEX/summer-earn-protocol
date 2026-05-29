import {
  calculateProposalTiming,
  formatTimeRemaining,
  formatTimestamp,
  getNextPhaseInfo,
  GOVERNANCE_TIMING,
  isTimeSensitive,
  PHASE_INFO,
  ProposalPhase,
} from '@/utils/timing'

const DAY = 24 * 60 * 60
const CREATED_AT = 1_700_000_000 // arbitrary fixed unix seconds
const VOTING_START = CREATED_AT + GOVERNANCE_TIMING.VOTING_DELAY
const VOTING_END = VOTING_START + GOVERNANCE_TIMING.VOTING_PERIOD
const TIMELOCK_END = VOTING_END + GOVERNANCE_TIMING.TIMELOCK_DELAY
const EXECUTION_DEADLINE = TIMELOCK_END + GOVERNANCE_TIMING.EXECUTION_GRACE_PERIOD

const proposalAt = (status: string) => ({ status, createdAt: String(CREATED_AT) })

describe('GOVERNANCE_TIMING constants', () => {
  it('uses the expected day-scaled durations', () => {
    expect(GOVERNANCE_TIMING.VOTING_DELAY).toBe(DAY)
    expect(GOVERNANCE_TIMING.VOTING_PERIOD).toBe(3 * DAY)
    expect(GOVERNANCE_TIMING.TIMELOCK_DELAY).toBe(2 * DAY)
    expect(GOVERNANCE_TIMING.EXECUTION_GRACE_PERIOD).toBe(14 * DAY)
  })
})

describe('PHASE_INFO', () => {
  it('has an entry for every ProposalPhase', () => {
    const phases: ProposalPhase[] = [
      'pending',
      'active',
      'succeeded',
      'queued',
      'executed',
      'expired',
    ]
    for (const p of phases) {
      expect(PHASE_INFO[p]).toBeDefined()
      expect(typeof PHASE_INFO[p].name).toBe('string')
      expect(typeof PHASE_INFO[p].description).toBe('string')
      expect(typeof PHASE_INFO[p].icon).toBe('string')
    }
  })
})

describe('calculateProposalTiming', () => {
  it('returns the pending phase when status=pending and currentTime before voting start', () => {
    const t = calculateProposalTiming(proposalAt('pending'), CREATED_AT + 100)
    expect(t.phase).toBe('pending')
    expect(t.nextPhase).toBe('active')
    expect(t.timeRemaining).toBeGreaterThan(0)
    expect(t.progressPercentage).toBeGreaterThanOrEqual(0)
    expect(t.progressPercentage).toBeLessThan(100)
  })

  it('promotes pending -> active when currentTime is inside the voting window', () => {
    const t = calculateProposalTiming(proposalAt('pending'), VOTING_START + 100)
    expect(t.phase).toBe('active')
    expect(t.nextPhase).toBe('succeeded')
    expect(t.timeRemaining).toBeGreaterThan(0)
  })

  it('returns active when status=active inside the voting window', () => {
    const t = calculateProposalTiming(proposalAt('active'), VOTING_START + 100)
    expect(t.phase).toBe('active')
    expect(t.nextPhaseTime).toBe(VOTING_END)
  })

  it('promotes active -> succeeded once voting end has passed', () => {
    const t = calculateProposalTiming(proposalAt('active'), VOTING_END + 1)
    expect(t.phase).toBe('succeeded')
    expect(t.nextPhase).toBe('queued')
    expect(t.timeRemaining).toBe(0)
    expect(t.progressPercentage).toBe(100)
  })

  it('promotes pending -> succeeded once voting end has passed', () => {
    const t = calculateProposalTiming(proposalAt('pending'), VOTING_END + 1)
    expect(t.phase).toBe('succeeded')
  })

  it('returns succeeded when status=succeeded', () => {
    const t = calculateProposalTiming(proposalAt('succeeded'), VOTING_END + 10)
    expect(t.phase).toBe('succeeded')
    expect(t.nextPhase).toBe('queued')
  })

  it('returns queued with countdown to timelock end', () => {
    const t = calculateProposalTiming(proposalAt('queued'), VOTING_END + 1000)
    expect(t.phase).toBe('queued')
    expect(t.nextPhase).toBe('executed')
    expect(t.nextPhaseTime).toBe(TIMELOCK_END)
  })

  it('returns executed when status=executed', () => {
    const t = calculateProposalTiming(proposalAt('executed'), VOTING_END + 1000)
    expect(t.phase).toBe('executed')
    expect(t.timeRemaining).toBe(0)
  })

  it('returns expired when currentTime is past the execution deadline and not executed', () => {
    const t = calculateProposalTiming(proposalAt('expired'), EXECUTION_DEADLINE + 1)
    expect(t.phase).toBe('expired')
  })

  it('clamps timeRemaining and progressPercentage to non-negative / <=100', () => {
    const t = calculateProposalTiming(proposalAt('pending'), VOTING_START + 100)
    expect(t.timeRemaining).toBeGreaterThanOrEqual(0)
    expect(t.progressPercentage).toBeGreaterThanOrEqual(0)
    expect(t.progressPercentage).toBeLessThanOrEqual(100)
  })

  it('defaults currentTime to the wall clock when not provided', () => {
    const t = calculateProposalTiming(proposalAt('pending'))
    expect(typeof t.currentTime).toBe('number')
    expect(t.currentTime).toBeGreaterThan(0)
  })
})

describe('formatTimeRemaining', () => {
  it('returns "0s" for non-positive input', () => {
    expect(formatTimeRemaining(0)).toBe('0s')
    expect(formatTimeRemaining(-5)).toBe('0s')
  })

  it('formats seconds only when under a minute', () => {
    expect(formatTimeRemaining(45)).toBe('45s')
  })

  it('formats minutes only', () => {
    expect(formatTimeRemaining(5 * 60)).toBe('5m')
  })

  it('formats hours and minutes', () => {
    expect(formatTimeRemaining(2 * 60 * 60 + 30 * 60)).toBe('2h 30m')
  })

  it('formats days, hours, and minutes', () => {
    expect(formatTimeRemaining(1 * DAY + 2 * 60 * 60 + 3 * 60)).toBe('1d 2h 3m')
  })

  it('omits seconds when there are larger units present', () => {
    expect(formatTimeRemaining(60 * 60 + 1)).toBe('1h')
  })

  it('is total (returns a string) for any positive input', () => {
    expect(typeof formatTimeRemaining(1)).toBe('string')
  })
})

describe('formatTimestamp', () => {
  it('returns "N/A" for zero or empty input', () => {
    expect(formatTimestamp(0)).toBe('N/A')
    expect(formatTimestamp('0')).toBe('N/A')
    expect(formatTimestamp('')).toBe('N/A')
  })

  it('renders a non-empty string for a real timestamp', () => {
    const out = formatTimestamp(1_700_000_000)
    expect(typeof out).toBe('string')
    expect(out.length).toBeGreaterThan(0)
    expect(out).toMatch(/2023/)
  })

  it('accepts numeric strings as input', () => {
    expect(formatTimestamp('1700000000')).toMatch(/2023/)
  })
})

describe('getNextPhaseInfo', () => {
  it('returns the next phase info for each non-terminal phase', () => {
    expect(getNextPhaseInfo('pending')).toBe(PHASE_INFO.active)
    expect(getNextPhaseInfo('active')).toBe(PHASE_INFO.succeeded)
    expect(getNextPhaseInfo('succeeded')).toBe(PHASE_INFO.queued)
    expect(getNextPhaseInfo('queued')).toBe(PHASE_INFO.executed)
  })

  it('returns null for terminal or unknown phases', () => {
    expect(getNextPhaseInfo('executed')).toBeNull()
    expect(getNextPhaseInfo('expired')).toBeNull()
  })
})

describe('isTimeSensitive', () => {
  it('returns true only for pending and active', () => {
    expect(isTimeSensitive('pending')).toBe(true)
    expect(isTimeSensitive('active')).toBe(true)
    expect(isTimeSensitive('succeeded')).toBe(false)
    expect(isTimeSensitive('queued')).toBe(false)
    expect(isTimeSensitive('executed')).toBe(false)
    expect(isTimeSensitive('expired')).toBe(false)
  })
})
