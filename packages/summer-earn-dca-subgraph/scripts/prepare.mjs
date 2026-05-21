#!/usr/bin/env node
// Render `subgraph.yaml` + `src/mappings/_bootstrapMap.ts` from the per-network
// config. Resolves Chainlink aggregator implementation addresses at the
// configured `feed-start-block` via `cast call <proxy> aggregator()(address)`
// so operators only have to edit the proxy addresses — moving the start block
// or rotating feeds doesn't require any manual lookup.
//
// Usage: pnpm exec node scripts/prepare.mjs <network>
// Reads config/<network>.json, requires `cast` (foundry) and `mustache` on PATH.
import { execFileSync } from 'node:child_process'
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

const NETWORK_DEFAULTS = {
  base: { rpcEnv: 'BASE_RPC_URL', rpcDefault: 'https://base.lava.build' },
  mainnet: { rpcEnv: 'MAINNET_RPC_URL', rpcDefault: 'https://eth.llamarpc.com' },
}

const ZERO = '0x0000000000000000000000000000000000000000'

function main() {
  const network = process.argv[2]
  if (!network) {
    fail(`usage: prepare.mjs <network>`)
  }
  const defaults = NETWORK_DEFAULTS[network]
  if (!defaults) {
    fail(`unknown network: ${network}`)
  }

  const configPath = `config/${network}.json`
  const config = JSON.parse(readFileSync(configPath, 'utf8'))

  const rpcUrl = process.env[defaults.rpcEnv] || defaults.rpcDefault
  const startBlock = String(config['feed-start-block'])

  config['usdc-feed-aggregator'] = resolveImpl(config['usdc-feed-proxy'], startBlock, rpcUrl)
  config['eth-feed-aggregator'] = resolveImpl(config['eth-feed-proxy'], startBlock, rpcUrl)

  const tmp = mkdtempSync(join(tmpdir(), 'dca-subgraph-prep-'))
  try {
    const enriched = join(tmp, 'enriched.json')
    writeFileSync(enriched, JSON.stringify(config, null, 2))
    render(enriched, 'subgraph.template.yaml', 'subgraph.yaml')
    render(enriched, 'src/mappings/_bootstrapMap.template.ts', 'src/mappings/_bootstrapMap.ts')
  } finally {
    rmSync(tmp, { recursive: true, force: true })
  }

  console.log(
    `prepared subgraph.yaml + _bootstrapMap.ts (network=${network}, feed-start-block=${startBlock})`,
  )
}

function resolveImpl(proxy, block, rpcUrl) {
  if (!proxy || proxy.toLowerCase() === ZERO) {
    return ZERO
  }
  const out = execFileSync(
    'cast',
    ['call', proxy, 'aggregator()(address)', '--rpc-url', rpcUrl, '--block', block],
    { encoding: 'utf8' },
  ).trim()
  if (!/^0x[0-9a-fA-F]{40}$/.test(out)) {
    fail(`cast returned unexpected output for ${proxy}@${block}: "${out}"`)
  }
  return out
}

function render(configPath, template, target) {
  const out = execFileSync('mustache', [configPath, template], { encoding: 'utf8' })
  writeFileSync(target, out)
}

function fail(msg) {
  console.error(`error: ${msg}`)
  process.exit(1)
}

main()
