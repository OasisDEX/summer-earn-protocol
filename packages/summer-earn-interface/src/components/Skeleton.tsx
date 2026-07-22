export function Skeleton({ className = '' }: { className?: string }) {
  return (
    <div
      className={`animate-pulse bg-white/5 rounded-md ${className}`}
      role="status"
      aria-label="Loading"
    />
  )
}
