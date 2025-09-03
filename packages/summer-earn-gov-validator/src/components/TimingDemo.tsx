'use client'

import { GOVERNANCE_TIMING, calculateProposalTiming } from '@/utils/timing'
import { useEffect, useState } from 'react'
import { CountdownTimer } from './CountdownTimer'
import { PhaseIndicator } from './PhaseIndicator'
import { ProgressBar } from './ProgressBar'

// Demo proposals with different phases
const DEMO_PROPOSALS = [
  {
    id: '1',
    status: 'pending',
    createdAt: (Date.now() / 1000 - 12 * 60 * 60).toString(), // 12 hours ago
    description: 'Pending proposal - voting starts in 12 hours',
  },
  {
    id: '2',
    status: 'pending',
    createdAt: (Date.now() / 1000 - 25 * 60 * 60).toString(), // 25 hours ago (should be active)
    description: 'Active proposal - voting is open',
  },
  {
    id: '3',
    status: 'succeeded',
    createdAt: (Date.now() / 1000 - 4 * 24 * 60 * 60).toString(), // 4 days ago
    description: 'Succeeded proposal - waiting for timelock',
  },
  {
    id: '4',
    status: 'queued',
    createdAt: (Date.now() / 1000 - 5 * 24 * 60 * 60).toString(), // 5 days ago
    description: 'Queued proposal - in timelock period',
  },
  {
    id: '5',
    status: 'executed',
    createdAt: (Date.now() / 1000 - 10 * 24 * 60 * 60).toString(), // 10 days ago
    description: 'Executed proposal - completed',
  },
]

export function TimingDemo() {
  const [currentTime, setCurrentTime] = useState(Date.now())

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentTime(Date.now())
    }, 1000)

    return () => clearInterval(interval)
  }, [])

  const timings = DEMO_PROPOSALS.map((proposal) => calculateProposalTiming(proposal))

  return (
    <div className="max-w-6xl mx-auto p-6 space-y-8">
      <div className="text-center space-y-4">
        <h1 className="text-3xl font-bold text-gray-900">Governance Timing Demo</h1>
        <p className="text-lg text-gray-600">
          Live countdown timers and progress bars for governance proposal phases
        </p>
        <div className="text-sm text-gray-500">
          Current time: {new Date(currentTime).toLocaleString()}
        </div>
      </div>

      {/* Timing Constants */}
      <div className="bg-gray-50 rounded-lg p-6">
        <h2 className="text-xl font-semibold mb-4">Governance Timing Constants</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-sm text-gray-500">Voting Delay</div>
            <div className="text-lg font-semibold">{GOVERNANCE_TIMING.VOTING_DELAY / 3600}h</div>
          </div>
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-sm text-gray-500">Voting Period</div>
            <div className="text-lg font-semibold">
              {GOVERNANCE_TIMING.VOTING_PERIOD / (24 * 3600)}d
            </div>
          </div>
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-sm text-gray-500">Timelock Delay</div>
            <div className="text-lg font-semibold">
              {GOVERNANCE_TIMING.TIMELOCK_DELAY / (24 * 3600)}d
            </div>
          </div>
          <div className="bg-white p-4 rounded-lg border">
            <div className="text-sm text-gray-500">Grace Period</div>
            <div className="text-lg font-semibold">
              {GOVERNANCE_TIMING.EXECUTION_GRACE_PERIOD / (24 * 3600)}d
            </div>
          </div>
        </div>
      </div>

      {/* Component Showcase */}
      <div className="space-y-6">
        <h2 className="text-2xl font-semibold">Component Showcase</h2>

        {DEMO_PROPOSALS.map((proposal, index) => {
          const timing = timings[index]

          return (
            <div
              key={proposal.id}
              className="bg-white border border-gray-200 rounded-lg p-6 space-y-6"
            >
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-lg font-semibold">Proposal #{proposal.id}</h3>
                  <p className="text-sm text-gray-600">{proposal.description}</p>
                </div>
                <div className="text-sm text-gray-500">
                  Created: {new Date(Number(proposal.createdAt) * 1000).toLocaleString()}
                </div>
              </div>

              {/* Phase Indicator Variants */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="space-y-3">
                  <h4 className="font-medium text-gray-700">Compact</h4>
                  <PhaseIndicator timing={timing} variant="compact" />
                </div>

                <div className="space-y-3">
                  <h4 className="font-medium text-gray-700">Default</h4>
                  <PhaseIndicator timing={timing} variant="default" />
                </div>

                <div className="space-y-3">
                  <h4 className="font-medium text-gray-700">Detailed</h4>
                  <PhaseIndicator timing={timing} variant="detailed" />
                </div>
              </div>

              {/* Individual Components */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-3">
                  <h4 className="font-medium text-gray-700">Countdown Timer</h4>
                  <CountdownTimer timing={timing} />
                </div>

                <div className="space-y-3">
                  <h4 className="font-medium text-gray-700">Progress Bar</h4>
                  <ProgressBar timing={timing} />
                </div>
              </div>

              {/* Timing Details */}
              <div className="bg-gray-50 rounded-lg p-4">
                <h4 className="font-medium text-gray-700 mb-3">Timing Details</h4>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                  <div>
                    <div className="text-gray-500">Current Phase</div>
                    <div className="font-medium">{timing.phase}</div>
                  </div>
                  <div>
                    <div className="text-gray-500">Progress</div>
                    <div className="font-medium">{Math.round(timing.progressPercentage)}%</div>
                  </div>
                  <div>
                    <div className="text-gray-500">Time Remaining</div>
                    <div className="font-medium">
                      {timing.timeRemaining > 0
                        ? `${Math.floor(timing.timeRemaining / 3600)}h`
                        : '0h'}
                    </div>
                  </div>
                  <div>
                    <div className="text-gray-500">Next Phase</div>
                    <div className="font-medium">{timing.nextPhase || 'N/A'}</div>
                  </div>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Usage Examples */}
      <div className="bg-blue-50 rounded-lg p-6">
        <h2 className="text-xl font-semibold mb-4">Usage Examples</h2>
        <div className="space-y-4 text-sm">
          <div>
            <h3 className="font-medium">Basic Phase Indicator:</h3>
            <code className="bg-white p-2 rounded block mt-1">
              {`<PhaseIndicator timing={timing} variant="compact" />`}
            </code>
          </div>
          <div>
            <h3 className="font-medium">Live Countdown:</h3>
            <code className="bg-white p-2 rounded block mt-1">
              {`<CountdownTimer timing={timing} showLabel={true} />`}
            </code>
          </div>
          <div>
            <h3 className="font-medium">Progress Bar:</h3>
            <code className="bg-white p-2 rounded block mt-1">
              {`<ProgressBar timing={timing} showPercentage={true} />`}
            </code>
          </div>
        </div>
      </div>
    </div>
  )
}
