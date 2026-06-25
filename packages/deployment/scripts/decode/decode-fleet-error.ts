import fs from 'fs'
import path from 'path'
import { type Abi, type AbiParameter, decodeErrorResult, type Hex } from 'viem'

/**
 * Decodes a custom error returned by the Superstate fleet stack (FleetCommanderWhitelist + Superstate
 * arks) from its 4-byte selector or full revert data.
 *
 * Usage:
 *   pnpm errors:decode 0x12345678                 # selector only -> error name + signature
 *   pnpm errors:decode 0x12345678....abcdef       # full revert data -> name + decoded arguments
 *   pnpm errors:decode --list                      # print the whole registry
 *
 * The registry is produced by generate-fleet-error-registry.ts (pnpm errors:generate). If you bump
 * the contracts, regenerate it.
 */

type RegistryEntry = {
  name: string
  signature: string
  inputs: readonly AbiParameter[]
  sources: string[]
}

const REGISTRY_PATH = path.resolve(__dirname, 'fleet-error-registry.json')

function loadRegistry(): Record<string, RegistryEntry> {
  if (!fs.existsSync(REGISTRY_PATH)) {
    throw new Error(
      `Registry not found at ${REGISTRY_PATH}. Run \`pnpm errors:generate\` first.`,
    )
  }
  return JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'))
}

function printList(registry: Record<string, RegistryEntry>) {
  const rows = Object.entries(registry).sort((a, b) => a[1].signature.localeCompare(b[1].signature))
  console.log(`${rows.length} known fleet/Superstate errors:\n`)
  for (const [selector, entry] of rows) {
    console.log(`  ${selector}  ${entry.signature}   [${entry.sources.join(', ')}]`)
  }
}

function stringify(value: unknown): string {
  return JSON.stringify(value, (_k, v) => (typeof v === 'bigint' ? v.toString() : v), 2)
}

function main() {
  const arg = process.argv[2]
  const registry = loadRegistry()

  if (!arg || arg === '--help' || arg === '-h') {
    console.log(
      'Usage:\n' +
        '  pnpm errors:decode 0x<selector>            decode a 4-byte selector\n' +
        '  pnpm errors:decode 0x<full revert data>    decode selector + arguments\n' +
        '  pnpm errors:decode --list                  list every known error',
    )
    process.exit(arg ? 0 : 1)
  }

  if (arg === '--list') {
    printList(registry)
    return
  }

  let data = arg.trim().toLowerCase()
  if (!data.startsWith('0x')) data = '0x' + data
  if (!/^0x[0-9a-f]*$/.test(data) || data.length < 10) {
    console.error(`Not a valid hex error. Expected at least a 4-byte selector (0x + 8 hex chars).`)
    process.exit(1)
  }

  const selector = data.slice(0, 10)
  const entry = registry[selector]

  if (!entry) {
    console.error(`✗ Unknown selector ${selector}.`)
    console.error(
      `  Not among the ${Object.keys(registry).length} known fleet/Superstate errors. ` +
        `It may come from another contract (token, external protocol). ` +
        `Try a generic 4-byte lookup (e.g. https://openchain.xyz/signatures?query=${selector}).`,
    )
    process.exit(1)
  }

  console.log(`✓ ${entry.signature}`)
  console.log(`  selector: ${selector}`)
  console.log(`  declared in: ${entry.sources.join(', ')}`)

  // If we only got the selector, there are no args to decode.
  if (data.length === 10) {
    if (entry.inputs.length > 0) {
      console.log(`  (selector only — pass the full revert data to decode the ${entry.inputs.length} argument(s))`)
    }
    return
  }

  try {
    const abi = [{ type: 'error', name: entry.name, inputs: entry.inputs }] as unknown as Abi
    const decoded = decodeErrorResult({ abi, data: data as Hex })
    const args = (decoded.args ?? []) as readonly unknown[]
    if (args.length === 0) {
      console.log('  (no arguments)')
      return
    }
    console.log('  arguments:')
    entry.inputs.forEach((input, i) => {
      const label = input.name ? `${input.name} (${input.type})` : `arg${i} (${input.type})`
      console.log(`    ${label}: ${stringify(args[i])}`)
    })
  } catch (err) {
    console.warn(`  (could not decode arguments: ${(err as Error).message})`)
  }
}

main()
