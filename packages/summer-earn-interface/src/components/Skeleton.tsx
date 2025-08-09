export function Skeleton({ className = '' }: { className?: string }) {
  return (
    <div
      className={`animate-pulse bg-gray-800/70 rounded-md ${className}`}
      role="status"
      aria-label="Loading"
    />
  )
}
