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

  const isUrgent = timeRemaining < 60 * 60 // Less than 1 hour
  const isCritical = timeRemaining < 60 * 15 // Less than 15 minutes
  const showUrgency = isTimeSensitive(timing.phase)

  return (
    <div className={`flex items-center space-x-2 ${className}`}>
      {showLabel && (
        <span className={`${sizeClasses[size]} font-medium text-gray-600 dark:text-gray-300`}>
          Time remaining:
        </span>
      )}
      <div
        className={`
          ${sizeClasses[size]} font-mono font-bold px-2 py-1 rounded
          ${
            showUrgency && isCritical
              ? 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300 border border-red-200 dark:border-red-800'
              : showUrgency && isUrgent
                ? 'bg-orange-100 dark:bg-orange-900/30 text-orange-800 dark:text-orange-300 border border-orange-200 dark:border-orange-800'
                : 'bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 border border-gray-200 dark:border-gray-700'
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

  const isUrgent = timeRemaining < 60 * 60 // Less than 1 hour
  const isCritical = timeRemaining < 60 * 15 // Less than 15 minutes
  const showUrgency = isTimeSensitive(timing.phase)

  return (
    <div
      className={`
        inline-flex items-center px-2 py-1 rounded-full text-xs font-mono font-bold
        ${
          showUrgency && isCritical
            ? 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300 border border-red-200 dark:border-red-800'
            : showUrgency && isUrgent
              ? 'bg-orange-100 dark:bg-orange-900/30 text-orange-800 dark:text-orange-300 border border-orange-200 dark:border-orange-800'
              : 'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 border border-blue-200 dark:border-blue-800'
        }
        ${className}
      `}
    >
      {formatTimeRemaining(timeRemaining)}
    </div>
  )
}
