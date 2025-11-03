'use client'

import { getNextPhaseInfo, isTimeSensitive, PHASE_INFO, type ProposalTiming } from '@/utils/timing'

import { CountdownTimer } from './CountdownTimer'
import { ProgressBar } from './ProgressBar'

interface PhaseIndicatorProps {
  timing: ProposalTiming
  className?: string
  variant?: 'default' | 'compact' | 'detailed'
}

export function PhaseIndicator({
  timing,
  className = '',
  variant = 'default',
}: PhaseIndicatorProps) {
  const phaseInfo = PHASE_INFO[timing.phase]
  const nextPhaseInfo = getNextPhaseInfo(timing.phase)
  const isUrgent = timing.timeRemaining < 60 * 60 // Less than 1 hour
  const isCritical = timing.timeRemaining < 60 * 15 // Less than 15 minutes

  if (variant === 'compact') {
    return (
      <div className={`flex items-center space-x-2 ${className}`}>
        <div className={`px-2 py-1 rounded-full text-xs font-medium border ${phaseInfo.color}`}>
          {phaseInfo.icon} {phaseInfo.name}
        </div>
        {isTimeSensitive(timing.phase) && timing.timeRemaining > 0 && (
          <CountdownTimer timing={timing} showLabel={false} size="sm" />
        )}
      </div>
    )
  }

  if (variant === 'detailed') {
    return (
      <div className={`space-y-4 ${className}`}>
        {/* Current Phase */}
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className={`px-3 py-2 rounded-lg text-sm font-medium border ${phaseInfo.color}`}>
              {phaseInfo.icon} {phaseInfo.name}
            </div>
            {isTimeSensitive(timing.phase) && timing.timeRemaining > 0 && (
              <CountdownTimer timing={timing} showLabel={false} size="md" />
            )}
          </div>
          {timing.nextPhase && nextPhaseInfo && (
            <div className="text-right">
              <div className="text-xs text-gray-500 dark:text-gray-400">Next phase</div>
              <div className="text-sm font-medium text-gray-700 dark:text-gray-300">
                {nextPhaseInfo.icon} {nextPhaseInfo.name}
              </div>
            </div>
          )}
        </div>

        {/* Progress Bar */}
        {isTimeSensitive(timing.phase) && (
          <ProgressBar timing={timing} showLabel={true} showPercentage={true} />
        )}

        {/* Phase Description */}
        <div className="text-sm text-gray-600 dark:text-gray-300">{phaseInfo.description}</div>

        {/* Next Phase Info */}
        {timing.nextPhase && nextPhaseInfo && timing.nextPhaseTime && (
          <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
            <div className="text-xs text-gray-500 dark:text-gray-400 mb-1">Upcoming</div>
            <div className="text-sm font-medium text-gray-700 dark:text-gray-300">
              {nextPhaseInfo.icon} {nextPhaseInfo.name}
            </div>
            <div className="text-xs text-gray-500 dark:text-gray-400 mt-1">
              {nextPhaseInfo.description}
            </div>
          </div>
        )}
      </div>
    )
  }

  // Default variant
  return (
    <div className={`space-y-3 ${className}`}>
      {/* Current Phase Header */}
      <div className="flex items-center justify-between">
        <div className={`px-3 py-2 rounded-lg text-sm font-medium border ${phaseInfo.color}`}>
          {phaseInfo.icon} {phaseInfo.name}
        </div>
        {isTimeSensitive(timing.phase) && timing.timeRemaining > 0 && (
          <CountdownTimer timing={timing} showLabel={false} size="sm" />
        )}
      </div>

      {/* Progress Bar */}
      {isTimeSensitive(timing.phase) && (
        <ProgressBar timing={timing} showLabel={false} showPercentage={true} />
      )}

      {/* Phase Description */}
      <div className="text-xs text-gray-600 dark:text-gray-300">{phaseInfo.description}</div>

      {/* Urgency Warning - only show for time-sensitive phases */}
      {isTimeSensitive(timing.phase) && isCritical && (
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-2">
          <div className="flex items-center space-x-2">
            <span className="text-red-500">⚠️</span>
            <span className="text-xs text-red-700 dark:text-red-300 font-medium">
              Critical: Less than 15 minutes remaining!
            </span>
          </div>
        </div>
      )}

      {isTimeSensitive(timing.phase) && isUrgent && !isCritical && (
        <div className="bg-orange-50 dark:bg-orange-900/20 border border-orange-200 dark:border-orange-800 rounded-lg p-2">
          <div className="flex items-center space-x-2">
            <span className="text-orange-500">⏰</span>
            <span className="text-xs text-orange-700 dark:text-orange-300 font-medium">
              Urgent: Less than 1 hour remaining
            </span>
          </div>
        </div>
      )}
    </div>
  )
}

interface PhaseTimelineProps {
  timing: ProposalTiming
  className?: string
}

export function PhaseTimeline({ timing, className = '' }: PhaseTimelineProps) {
  const phases = ['pending', 'active', 'succeeded', 'queued', 'executed'] as const
  const currentPhaseIndex = phases.indexOf(timing.phase as any)

  return (
    <div className={`space-y-4 ${className}`}>
      <div className="text-sm font-medium text-gray-700 mb-3">Governance Timeline</div>

      <div className="space-y-3">
        {phases.map((phase, index) => {
          const phaseInfo = PHASE_INFO[phase]
          const isActive = index === currentPhaseIndex
          const isCompleted = index < currentPhaseIndex

          return (
            <div key={phase} className="flex items-center space-x-3">
              {/* Phase Icon */}
              <div
                className={`
                  w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0
                  ${
                    isCompleted
                      ? 'bg-green-500 text-white'
                      : isActive
                        ? 'bg-blue-500 text-white'
                        : 'bg-gray-200 text-gray-500'
                  }
                `}
              >
                {isCompleted ? '✓' : phaseInfo.icon}
              </div>

              {/* Phase Info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center space-x-2">
                  <span
                    className={`text-sm font-medium ${isActive ? 'text-blue-600' : 'text-gray-700'}`}
                  >
                    {phaseInfo.name}
                  </span>
                  {isActive && isTimeSensitive(phase) && timing.timeRemaining > 0 && (
                    <CountdownTimer timing={timing} showLabel={false} size="sm" />
                  )}
                </div>
                <div className="text-xs text-gray-500 mt-1">{phaseInfo.description}</div>
                {isActive && isTimeSensitive(phase) && (
                  <div className="mt-2">
                    <ProgressBar timing={timing} showLabel={false} showPercentage={true} />
                  </div>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

interface QuickPhaseStatusProps {
  timing: ProposalTiming
  className?: string
}

export function QuickPhaseStatus({ timing, className = '' }: QuickPhaseStatusProps) {
  const phaseInfo = PHASE_INFO[timing.phase]
  const isUrgent = timing.timeRemaining < 60 * 60
  const isCritical = timing.timeRemaining < 60 * 15

  return (
    <div className={`flex items-center space-x-2 ${className}`}>
      <div className={`px-2 py-1 rounded-full text-xs font-medium border ${phaseInfo.color}`}>
        {phaseInfo.icon} {phaseInfo.name}
      </div>
      {isTimeSensitive(timing.phase) && timing.timeRemaining > 0 && (
        <div
          className={`
            px-2 py-1 rounded-full text-xs font-mono font-bold
            ${
              isCritical
                ? 'bg-red-100 text-red-800 border border-red-200'
                : isUrgent
                  ? 'bg-orange-100 text-orange-800 border border-orange-200'
                  : 'bg-blue-100 text-blue-800 border border-blue-200'
            }
          `}
        >
          {timing.timeRemaining > 0 ? `${Math.floor(timing.timeRemaining / 3600)}h` : '0h'}
        </div>
      )}
    </div>
  )
}
