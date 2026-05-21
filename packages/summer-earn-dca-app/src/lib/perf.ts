// Tiny manual-instrumentation helper. Wrap any async call to log the wall
// clock with a `[perf]` prefix that's easy to filter in DevTools / Next
// dev-server output. Disable per-environment with NEXT_PUBLIC_PERF_LOG=0.
//
// Lives in `src/lib` so it can be imported from both client hooks and
// server route handlers — both have `performance.now()` and `console`.

const ENABLED =
  typeof process === 'undefined' || process.env.NEXT_PUBLIC_PERF_LOG !== '0'

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

// Synchronous mark for non-Promise paths (e.g. parsing, big JSON shapes).
export function mark<T>(label: string, fn: () => T): T {
  if (!ENABLED) return fn()
  const start = performance.now()
  const result = fn()
  const ms = (performance.now() - start).toFixed(0)
  console.log(`[perf] ${label} ${ms}ms`)
  return result
}
