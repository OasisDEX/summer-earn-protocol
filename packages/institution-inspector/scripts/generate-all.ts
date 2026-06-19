import { generate } from './generate-graph'
import type { Env } from './build-config-graph'

/**
 * Regenerate every network/env graph. Add a network here once its config + Ignition
 * deployment + RPC (config/chains.ts) exist; empty combos are skipped automatically.
 *
 *   pnpm generate:all            # config + Ignition only
 *   pnpm generate:all --onchain  # + on-chain verification
 */
const TARGETS: Array<{ network: string; env: Env }> = [
  { network: 'base', env: 'production' },
  { network: 'base', env: 'staging' },
  { network: 'mainnet', env: 'production' },
  { network: 'mainnet', env: 'staging' },
  { network: 'sepolia_mainnet', env: 'staging' },
]

async function main() {
  const withOnchain = process.argv.includes('--onchain')
  console.log(`Regenerating ${TARGETS.length} graph(s) (onchain=${withOnchain})…`)
  for (const t of TARGETS) {
    try {
      await generate(t.network, t.env, withOnchain)
    } catch (e) {
      console.error(`✗ ${t.network}/${t.env}: ${e instanceof Error ? e.message : String(e)}`)
    }
  }
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
