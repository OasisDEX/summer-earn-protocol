'use client'

import { useEffect, useState } from 'react'

import { isTimeSensitive, PHASE_INFO, type ProposalTiming } from '@/utils/timing'

interface ProgressBarProps {
  timing: ProposalTiming
  className?: string
  showLabel?: boolean
  showPercentage?: boolean
  animated?: boolean
}

export function ProgressBar({
  timing,
  className = '',
  showLabel = true,
  showPercentage = true,
  animated = true,
}: ProgressBarProps) {
  const [displayProgress, setDisplayProgress] = useState(0)

  useEffect(() => {
    if (!animated) {
      setDisplayProgress(timing.progressPercentage)
      return
    }

    // Animate progress bar
    const duration = 1000 // 1 second animation
    const startTime = Date.now()
    const startProgress = displayProgress
    const targetProgress = timing.progressPercentage

    const animate = () => {
      const elapsed = Date.now() - startTime
      const progress = Math.min(elapsed / duration, 1)

      const currentProgress = startProgress + (targetProgress - startProgress) * progress
      setDisplayProgress(currentProgress)

      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }

    requestAnimationFrame(animate)
  }, [timing.progressPercentage, animated, displayProgress])

  const phaseInfo = PHASE_INFO[timing.phase]
  const isComplete = timing.progressPercentage >= 100
  const isUrgent = timing.timeRemaining < 60 * 60 // Less than 1 hour
  const showUrgency = isTimeSensitive(timing.phase)

  return (
    <div className={`space-y-2 ${className}`}>
      {showLabel && (
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <span className="text-sm font-medium text-gray-700 dark:text-gray-300">
              {phaseInfo.icon} {phaseInfo.name}
            </span>
            {timing.nextPhase && (
              <span className="text-xs text-gray-500 dark:text-gray-400">
                → {PHASE_INFO[timing.nextPhase].name}
              </span>
            )}
          </div>
          {showPercentage && (
            <span className="text-sm font-mono text-gray-600 dark:text-gray-400">
              {Math.round(displayProgress)}%
            </span>
          )}
        </div>
      )}

      <div className="relative">
        <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2 overflow-hidden">
          <div
            className={`
              h-full rounded-full transition-all duration-300 ease-out
              ${
                isComplete ? 'bg-green-500' : showUrgency && isUrgent ? 'bg-red-500' : 'bg-blue-500'
              }
            `}
            style={{ width: `${displayProgress}%` }}
          />
        </div>

        {/* Phase markers */}
        <div className="absolute inset-0 flex items-center">
          {timing.phase === 'pending' && (
            <div className="absolute left-0 w-1 h-3 bg-yellow-400 rounded-full transform -translate-x-0.5" />
          )}
          {timing.phase === 'active' && (
            <div className="absolute left-0 w-1 h-3 bg-blue-400 rounded-full transform -translate-x-0.5" />
          )}
          {timing.phase === 'queued' && (
            <div className="absolute left-0 w-1 h-3 bg-purple-400 rounded-full transform -translate-x-0.5" />
          )}
        </div>
      </div>

      {showLabel && (
        <p className="text-xs text-gray-500 dark:text-gray-400">{phaseInfo.description}</p>
      )}
    </div>
  )
}

interface CompactProgressBarProps {
  timing: ProposalTiming
  className?: string
}

export function CompactProgressBar({ timing, className = '' }: CompactProgressBarProps) {
  const [displayProgress, setDisplayProgress] = useState(0)

  useEffect(() => {
    const duration = 500 // 0.5 second animation
    const startTime = Date.now()
    const startProgress = displayProgress
    const targetProgress = timing.progressPercentage

    const animate = () => {
      const elapsed = Date.now() - startTime
      const progress = Math.min(elapsed / duration, 1)

      const currentProgress = startProgress + (targetProgress - startProgress) * progress
      setDisplayProgress(currentProgress)

      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }

    requestAnimationFrame(animate)
  }, [timing.progressPercentage, displayProgress])

  const isUrgent = timing.timeRemaining < 60 * 60
  const showUrgency = isTimeSensitive(timing.phase)

  return (
    <div className={`flex items-center space-x-2 ${className}`}>
      <div className="flex-1 bg-gray-200 dark:bg-gray-700 rounded-full h-1.5 overflow-hidden">
        <div
          className={`
            h-full rounded-full transition-all duration-300 ease-out
            ${showUrgency && isUrgent ? 'bg-red-500' : 'bg-blue-500'}
          `}
          style={{ width: `${displayProgress}%` }}
        />
      </div>
      <span className="text-xs text-gray-500 dark:text-gray-400 font-mono">
        {Math.round(displayProgress)}%
      </span>
    </div>
  )
}

interface PhaseProgressBarProps {
  timing: ProposalTiming
  className?: string
}

export function PhaseProgressBar({ timing, className = '' }: PhaseProgressBarProps) {
  const phases = ['pending', 'active', 'succeeded', 'queued', 'executed'] as const
  const currentPhaseIndex = phases.indexOf(timing.phase as any)

  return (
    <div className={`space-y-3 ${className}`}>
      <div className="flex items-center justify-between">
        {phases.map((phase, index) => {
          const phaseInfo = PHASE_INFO[phase]
          const isActive = index === currentPhaseIndex
          const isCompleted = index < currentPhaseIndex

          return (
            <div key={phase} className="flex flex-col items-center space-y-1">
              <div
                className={`
                  w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold
                  ${
                    isCompleted
                      ? 'bg-green-500 text-white'
                      : isActive
                        ? 'bg-blue-500 text-white'
                        : 'bg-gray-200 dark:bg-gray-700 text-gray-500 dark:text-gray-400'
                  }
                `}
              >
                {isCompleted ? '✓' : phaseInfo.icon}
              </div>
              <span
                className={`text-xs font-medium ${isActive ? 'text-blue-600 dark:text-blue-400' : 'text-gray-500 dark:text-gray-400'}`}
              >
                {phaseInfo.name}
              </span>
            </div>
          )
        })}
      </div>

      {/* Connection lines */}
      <div className="relative">
        <div className="absolute top-0 left-0 right-0 h-0.5 bg-gray-200 dark:bg-gray-700" />
        <div
          className="absolute top-0 left-0 h-0.5 bg-blue-500 transition-all duration-500"
          style={{
            width: `${(currentPhaseIndex / (phases.length - 1)) * 100}%`,
          }}
        />
      </div>
    </div>
  )
}
