// Opt-in via NEXT_PUBLIC_PERF_LOG=1 (or true/yes/on).

function isEnabled(): boolean {
  if (typeof process === 'undefined') return false
  const raw = process.env.NEXT_PUBLIC_PERF_LOG
  if (!raw) return false
  const v = raw.toLowerCase()
  return v === '1' || v === 'true' || v === 'yes' || v === 'on'
}

const ENABLED = isEnabled()

export async function time<T>(label: string, fn: () => Promise<T>): Promise<T> {
  if (!ENABLED) return fn()
  const start = performance.now()
  try {
    const result = await fn()
    const ms = (performance.now() - start).toFixed(0)
    console.log(`[perf] ${label} ${ms}ms`)
    return result
  } catch (err) {
    const ms = (performance.now() - start).toFixed(0)
    console.log(`[perf] ${label} ${ms}ms ✗ ${(err as Error)?.message ?? err}`)
    throw err
  }
}

export function mark<T>(label: string, fn: () => T): T {
  if (!ENABLED) return fn()
  const start = performance.now()
  const result = fn()
  const ms = (performance.now() - start).toFixed(0)
  console.log(`[perf] ${label} ${ms}ms`)
  return result
}
