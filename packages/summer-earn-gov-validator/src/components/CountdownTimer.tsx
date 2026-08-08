'use client'

import { useEffect, useState } from 'react'

import { formatTimeRemaining, isTimeSensitive, type ProposalTiming } from '@/utils/timing'

interface CountdownTimerProps {
  timing: ProposalTiming
  className?: string
  showLabel?: boolean
  size?: 'sm' | 'md' | 'lg'
}

export function CountdownTimer({
  timing,
  className = '',
  showLabel = true,
  size = 'md',
}: CountdownTimerProps) {
  const [timeRemaining, setTimeRemaining] = useState(timing.timeRemaining)

  useEffect(() => {
    if (timing.timeRemaining <= 0) {
      setTimeRemaining(0)
      return
    }

    const interval = setInterval(() => {
      setTimeRemaining((prev) => {
        const newTime = prev - 1
        return newTime <= 0 ? 0 : newTime
      })
    }, 1000)

    return () => clearInterval(interval)
  }, [timing.timeRemaining])

  const sizeClasses = {
    sm: 'text-xs',
    md: 'text-sm',
    lg: 'text-base',
  }

  const isUrgent = timeRemaining < 60 * 60
  const isCritical = timeRemaining < 60 * 15
  const showUrgency = isTimeSensitive(timing.phase)

  return (
    <div className={`flex items-center space-x-2 ${className}`}>
      {showLabel && (
        <span className={`${sizeClasses[size]} font-medium text-fg3`}>
          Time remaining:
        </span>
      )}
      <div
        className={`
          ${sizeClasses[size]} font-mono font-semibold px-2 py-0.5 rounded border
          ${
            showUrgency && isCritical
              ? 'bg-crit-bg text-crit border-crit/30'
              : showUrgency && isUrgent
                ? 'bg-warn-bg text-warn border-warn/30'
                : 'bg-surface3 text-fg border-line2'
          }
        `}
      >
        {formatTimeRemaining(timeRemaining)}
      </div>
    </div>
  )
}

interface CompactCountdownProps {
  timing: ProposalTiming
  className?: string
}

export function CompactCountdown({ timing, className = '' }: CompactCountdownProps) {
  const [timeRemaining, setTimeRemaining] = useState(timing.timeRemaining)

  useEffect(() => {
    if (timing.timeRemaining <= 0) {
      setTimeRemaining(0)
      return
    }

    const interval = setInterval(() => {
      setTimeRemaining((prev) => {
        const newTime = prev - 1
        return newTime <= 0 ? 0 : newTime
      })
    }, 1000)

    return () => clearInterval(interval)
  }, [timing.timeRemaining])

  const isUrgent = timeRemaining < 60 * 60
  const isCritical = timeRemaining < 60 * 15
  const showUrgency = isTimeSensitive(timing.phase)

  return (
    <div
      className={`
        inline-flex items-center px-2 py-0.5 rounded-full text-xs font-mono font-semibold border
        ${
          showUrgency && isCritical
            ? 'bg-crit-bg text-crit border-crit/30'
            : showUrgency && isUrgent
              ? 'bg-warn-bg text-warn border-warn/30'
              : 'bg-pink-bg text-brand-pink border-brand-pink/30'
        }
        ${className}
      `}
    >
      {formatTimeRemaining(timeRemaining)}
    </div>
  )
}
