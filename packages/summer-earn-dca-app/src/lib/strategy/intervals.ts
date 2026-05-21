// Contract enforces interval >= 1 day and aligns nextTriggerAt to the
// next hour boundary.

export const ONE_DAY_SECONDS = BigInt(24 * 60 * 60)
export const THREE_DAYS_SECONDS = ONE_DAY_SECONDS * 3n
export const ONE_WEEK_SECONDS = ONE_DAY_SECONDS * 7n
export const TWO_WEEKS_SECONDS = ONE_WEEK_SECONDS * 2n
export const FOUR_WEEKS_SECONDS = ONE_WEEK_SECONDS * 4n
export const MIN_INTERVAL_SECONDS = ONE_DAY_SECONDS

export interface IntervalPreset {
  label: string
  seconds: bigint
}

export const INTERVAL_PRESETS: readonly IntervalPreset[] = [
  { label: 'Daily', seconds: ONE_DAY_SECONDS },
  { label: 'Every 3 days', seconds: THREE_DAYS_SECONDS },
  { label: 'Weekly', seconds: ONE_WEEK_SECONDS },
  { label: 'Bi-weekly', seconds: TWO_WEEKS_SECONDS },
  { label: 'Monthly (4 weeks)', seconds: FOUR_WEEKS_SECONDS },
] as const

export function validateInterval(seconds: bigint): { ok: boolean; reason?: string } {
  if (seconds < MIN_INTERVAL_SECONDS) {
    return { ok: false, reason: 'Interval must be at least 1 day' }
  }
  return { ok: true }
}

// Matches the contract's ((block.timestamp + 3599) / 3600) * 3600.
export function nextHourAligned(timestampSeconds: bigint): bigint {
  return ((timestampSeconds + 3599n) / 3600n) * 3600n
}

export function predictedNextTriggerAtCreation(
  intervalSeconds: bigint,
  nowSeconds = BigInt(Math.floor(Date.now() / 1000)),
): bigint {
  return nextHourAligned(nowSeconds) + intervalSeconds
}

export function formatCountdown(
  targetUnix: bigint,
  nowSeconds = BigInt(Math.floor(Date.now() / 1000)),
): string {
  const delta = targetUnix - nowSeconds
  if (delta <= 0n) return 'Ready'
  const days = delta / 86_400n
  const hours = (delta % 86_400n) / 3600n
  const minutes = (delta % 3600n) / 60n
  if (days > 0n) return `${days}d ${hours}h`
  if (hours > 0n) return `${hours}h ${minutes}m`
  return `${minutes}m`
}
