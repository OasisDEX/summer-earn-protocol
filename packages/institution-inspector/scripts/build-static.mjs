// Static-export build for hosting (AWS Amplify, platform WEB — the Amplify buildspec in
// infrastructure/modules/amplify_app runs `pnpm run build:static` for this package).
//
// The viewer only renders the committed data/*.json snapshots, so it can ship as a fully
// static site (output: 'export') with zero serverless functions. The catch: the dynamic
// /api/refresh route handler cannot be part of a static export (it requires a literal
// `dynamic = 'force-static'`, which would break the live on-chain refresh used in local dev).
//
// So for the export build we move app/api out of the tree, run `next build` with
// NEXT_PUBLIC_STATIC_EXPORT=1, then restore it in a finally — leaving the route fully intact
// for `next dev` and regular SSR builds. The move is restored even if the build fails.
import { existsSync, renameSync, rmSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import path from 'node:path'

const ROUTE_DIR = path.join(process.cwd(), 'app', 'api')
const STASH_DIR = path.join(process.cwd(), '.api-stash')

function restore() {
  if (existsSync(STASH_DIR)) {
    rmSync(ROUTE_DIR, { recursive: true, force: true })
    renameSync(STASH_DIR, ROUTE_DIR)
  }
}

// Clean up any stash left behind by an interrupted previous run, then stash the route.
rmSync(STASH_DIR, { recursive: true, force: true })
if (existsSync(ROUTE_DIR)) {
  console.log('[build-static] stashing app/api for the static export…')
  renameSync(ROUTE_DIR, STASH_DIR)
}

try {
  const res = spawnSync('pnpm', ['exec', 'next', 'build'], {
    stdio: 'inherit',
    env: { ...process.env, NEXT_PUBLIC_STATIC_EXPORT: '1' },
  })
  process.exitCode = res.status ?? 1
} finally {
  restore()
  console.log('[build-static] restored app/api')
}
