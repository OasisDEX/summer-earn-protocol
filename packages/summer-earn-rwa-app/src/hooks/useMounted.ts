'use client'

import { useEffect, useState } from 'react'

/**
 * Returns `true` only after the component has mounted on the client.
 *
 * Use this to gate any rendering that depends on browser-only state
 * (wagmi `useAccount`, `localStorage`, `window`, user-locale dates, …) so
 * the server pass and the first client render produce identical output
 * and React's hydration step doesn't bail out. The official Next.js
 * recommendation for this category of mismatch:
 *
 *   "Render a stable fallback on the server and update that part after
 *    mount."
 *   — node_modules/next/dist/docs/01-app/03-api-reference/04-functions/
 *     use-pathname.md, "Avoid hydration mismatch with rewrites"
 *
 * `useEffect` runs strictly *after* hydration commits, so anything gated
 * behind this flag cannot participate in the hydration diff.
 */
export function useMounted(): boolean {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  return mounted
}
