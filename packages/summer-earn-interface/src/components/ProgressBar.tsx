'use client'

interface ProgressBarProps {
  value: number
  max?: number
  className?: string
  showGlow?: boolean
}

export function ProgressBar({
  value,
  max = 100,
  className = '',
  showGlow = false,
}: ProgressBarProps) {
  const percentage = Math.min(100, Math.max(0, (value / max) * 100))

  return (
    <div className={`w-full h-1.5 bg-white/5 rounded-full overflow-hidden ${className}`}>
      <div
        className={`bg-primary h-full transition-all ${showGlow ? 'shadow-[0_0_8px_rgba(255,46,143,0.5)]' : ''}`}
        style={{ width: `${percentage}%` }}
      />
    </div>
  )
}
