// Governance timing constants and utilities
export const GOVERNANCE_TIMING = {
  // Time from proposal creation to voting start
  VOTING_DELAY: 24 * 60 * 60, // 24 hours in seconds

  // Time for voting period (typically 3-7 days)
  VOTING_PERIOD: 3 * 24 * 60 * 60, // 3 days in seconds

  // Time from voting end to execution (timelock delay)
  TIMELOCK_DELAY: 2 * 24 * 60 * 60, // 2 days in seconds

  // Grace period for execution after timelock expires
  EXECUTION_GRACE_PERIOD: 14 * 24 * 60 * 60, // 14 days in seconds
} as const

export type ProposalPhase = 'pending' | 'active' | 'succeeded' | 'queued' | 'executed' | 'expired'

export interface ProposalTiming {
  phase: ProposalPhase
  currentTime: number
  createdAt: number
  votingStartTime: number
  votingEndTime: number
  timelockStartTime: number
  timelockEndTime: number
  executionDeadline: number
  timeRemaining: number
  progressPercentage: number
  nextPhase?: ProposalPhase
  nextPhaseTime?: number
}

export interface PhaseInfo {
  name: string
  description: string
  duration: number
  color: string
  icon: string
}

export const PHASE_INFO: Record<ProposalPhase, PhaseInfo> = {
  pending: {
    name: 'Pending',
    description: 'Waiting for voting to begin',
    duration: GOVERNANCE_TIMING.VOTING_DELAY,
    color: 'bg-yellow-100 text-yellow-800 border-yellow-200',
    icon: '⏳',
  },
  active: {
    name: 'Active',
    description: 'Voting is now open',
    duration: GOVERNANCE_TIMING.VOTING_PERIOD,
    color: 'bg-blue-100 text-blue-800 border-blue-200',
    icon: '🗳️',
  },
  succeeded: {
    name: 'Succeeded',
    description: 'Voting passed, waiting for timelock',
    duration: 0, // Immediate transition
    color: 'bg-green-100 text-green-800 border-green-200',
    icon: '✅',
  },
  queued: {
    name: 'Queued',
    description: 'In timelock, waiting for execution',
    duration: GOVERNANCE_TIMING.TIMELOCK_DELAY,
    color: 'bg-purple-100 text-purple-800 border-purple-200',
    icon: '⏰',
  },
  executed: {
    name: 'Executed',
    description: 'Proposal has been executed',
    duration: 0,
    color: 'bg-gray-100 text-gray-800 border-gray-200',
    icon: '🎯',
  },
  expired: {
    name: 'Expired',
    description: 'Execution deadline has passed',
    duration: 0,
    color: 'bg-red-100 text-red-800 border-red-200',
    icon: '❌',
  },
}

/**
 * Calculate the current phase and timing information for a proposal
 */
export function calculateProposalTiming(proposal: {
  status: string
  createdAt: string
}): ProposalTiming {
  const currentTime = Math.floor(Date.now() / 1000)
  const createdAt = Number(proposal.createdAt)
  const baseStatus = proposal.status.toLowerCase() as ProposalPhase

  // Calculate all timing milestones
  const votingStartTime = createdAt + GOVERNANCE_TIMING.VOTING_DELAY
  const votingEndTime = votingStartTime + GOVERNANCE_TIMING.VOTING_PERIOD
  const timelockStartTime = votingEndTime
  const timelockEndTime = timelockStartTime + GOVERNANCE_TIMING.TIMELOCK_DELAY
  const executionDeadline = timelockEndTime + GOVERNANCE_TIMING.EXECUTION_GRACE_PERIOD

  // Determine current phase based on timing and status
  let phase: ProposalPhase = baseStatus
  let timeRemaining = 0
  let progressPercentage = 0
  let nextPhase: ProposalPhase | undefined
  let nextPhaseTime: number | undefined

  if (currentTime < votingStartTime && baseStatus === 'pending') {
    // Still in pending phase
    phase = 'pending'
    timeRemaining = votingStartTime - currentTime
    progressPercentage = ((currentTime - createdAt) / GOVERNANCE_TIMING.VOTING_DELAY) * 100
    nextPhase = 'active'
    nextPhaseTime = votingStartTime
  } else if (
    currentTime >= votingStartTime &&
    currentTime < votingEndTime &&
    baseStatus === 'pending'
  ) {
    // Voting is active (pending status but past voting start time)
    phase = 'active'
    timeRemaining = votingEndTime - currentTime
    progressPercentage = ((currentTime - votingStartTime) / GOVERNANCE_TIMING.VOTING_PERIOD) * 100
    nextPhase = 'succeeded'
    nextPhaseTime = votingEndTime
  } else if (
    (baseStatus === 'active' || (baseStatus === 'pending' && currentTime >= votingStartTime)) &&
    currentTime < votingEndTime
  ) {
    // Active voting
    phase = 'active'
    timeRemaining = votingEndTime - currentTime
    progressPercentage = ((currentTime - votingStartTime) / GOVERNANCE_TIMING.VOTING_PERIOD) * 100
    nextPhase = 'succeeded'
    nextPhaseTime = votingEndTime
  } else if (
    (baseStatus === 'active' || (baseStatus === 'pending' && currentTime >= votingStartTime)) &&
    currentTime >= votingEndTime
  ) {
    // Voting period ended, should be succeeded
    phase = 'succeeded'
    timeRemaining = 0
    progressPercentage = 100
    nextPhase = 'queued'
    nextPhaseTime = timelockStartTime
  } else if (baseStatus === 'succeeded') {
    // Voting succeeded, waiting for timelock
    phase = 'succeeded'
    timeRemaining = 0
    progressPercentage = 100
    nextPhase = 'queued'
    nextPhaseTime = timelockStartTime
  } else if (baseStatus === 'queued') {
    // In timelock
    phase = 'queued'
    timeRemaining = timelockEndTime - currentTime
    progressPercentage =
      ((currentTime - timelockStartTime) / GOVERNANCE_TIMING.TIMELOCK_DELAY) * 100
    nextPhase = 'executed'
    nextPhaseTime = timelockEndTime
  } else if (baseStatus === 'executed') {
    // Already executed
    phase = 'executed'
    timeRemaining = 0
    progressPercentage = 100
  } else if (currentTime > executionDeadline && baseStatus.toLowerCase() !== 'executed') {
    // Expired
    phase = 'expired'
    timeRemaining = 0
    progressPercentage = 100
  }

  return {
    phase,
    currentTime,
    createdAt,
    votingStartTime,
    votingEndTime,
    timelockStartTime,
    timelockEndTime,
    executionDeadline,
    timeRemaining: Math.max(0, timeRemaining),
    progressPercentage: Math.min(100, Math.max(0, progressPercentage)),
    nextPhase,
    nextPhaseTime,
  }
}

/**
 * Format time remaining in a human-readable format
 */
export function formatTimeRemaining(seconds: number): string {
  if (seconds <= 0) return '0s'

  const days = Math.floor(seconds / (24 * 60 * 60))
  const hours = Math.floor((seconds % (24 * 60 * 60)) / (60 * 60))
  const minutes = Math.floor((seconds % (60 * 60)) / 60)
  const secs = seconds % 60

  const parts: string[] = []
  if (days > 0) parts.push(`${days}d`)
  if (hours > 0) parts.push(`${hours}h`)
  if (minutes > 0) parts.push(`${minutes}m`)
  if (secs > 0 && days === 0) parts.push(`${secs}s`) // Only show seconds if less than a day

  return parts.join(' ')
}

/**
 * Get the next phase information
 */
export function getNextPhaseInfo(currentPhase: ProposalPhase): PhaseInfo | null {
  const phaseOrder: ProposalPhase[] = ['pending', 'active', 'succeeded', 'queued', 'executed']
  const currentIndex = phaseOrder.indexOf(currentPhase)

  if (currentIndex === -1 || currentIndex >= phaseOrder.length - 1) {
    return null
  }

  return PHASE_INFO[phaseOrder[currentIndex + 1]]
}

/**
 * Check if a proposal is in a time-sensitive phase where users can take action
 */
export function isTimeSensitive(phase: ProposalPhase): boolean {
  return ['pending', 'active'].includes(phase)
}
