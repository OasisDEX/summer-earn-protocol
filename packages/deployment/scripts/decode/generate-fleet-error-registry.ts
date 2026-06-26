import fs from 'fs'
import path from 'path'
import { type Abi, type AbiParameter, toFunctionSelector } from 'viem'

// viem doesn't re-export abitype's `AbiError`, so we describe just the shape we read off the ABI.
type AbiErrorItem = { type: 'error'; name: string; inputs: readonly AbiParameter[] }

/**
 * Generates a registry of every custom error that the deployed Superstate fleet stack can revert
 * with, keyed by 4-byte selector. The compiled artifact ABIs already include all inherited and
 * imported errors (ERC4626, OZ access control, the Tipper, the Ark base classes, etc.), so we just
 * union the error fragments across the relevant contracts.
 *
 * Run with: pnpm errors:generate
 * Consumes:  decode-fleet-error.ts (the CLI decoder reads the JSON this writes).
 */

// Contracts that make up the Superstate fleet deposit/board path on Sepolia.
// <ArtifactName> resolves to core-contracts/out/<ArtifactName>.sol/<ArtifactName>.json
const TARGET_CONTRACTS = [
  'FleetCommanderWhitelist', // the deposit entry point (the deployed fleet)
  'FleetCommander', // base fleet (shared errors)
  'FleetCommanderConfigProvider',
  'SuperstateSubscribeArk', // USTB ark
  'SuperstateStandardArk', // USCC ark
  'SuperstateArk', // shared ark base
] as const

const OUT_DIR = path.resolve(__dirname, '../../../core-contracts/out')
const REGISTRY_PATH = path.resolve(__dirname, 'fleet-error-registry.json')

/** Canonical signature for an error fragment, e.g. `Foo(uint256,(address,bytes32)[])`. */
function canonicalType(input: AbiParameter): string {
  if (input.type.startsWith('tuple')) {
    const components = (input as { components?: readonly AbiParameter[] }).components ?? []
    const inner = components.map(canonicalType).join(',')
    // preserve any array suffix on the tuple, e.g. tuple[] -> (...)[]
    const suffix = input.type.slice('tuple'.length)
    return `(${inner})${suffix}`
  }
  return input.type
}

function errorSignature(err: AbiErrorItem): string {
  return `${err.name}(${err.inputs.map(canonicalType).join(',')})`
}

type RegistryEntry = {
  name: string
  signature: string
  // Full ABI inputs (incl. tuple `components`) so the decoder can reconstruct a valid AbiError
  // and decode arguments — including nested tuples — without re-reading the artifacts.
  inputs: readonly unknown[]
  sources: string[]
}

function main() {
  const registry: Record<string, RegistryEntry> = {}
  const collisions: string[] = []

  for (const contract of TARGET_CONTRACTS) {
    const artifactPath = path.join(OUT_DIR, `${contract}.sol`, `${contract}.json`)
    if (!fs.existsSync(artifactPath)) {
      console.warn(`! skipping ${contract}: artifact not found at ${artifactPath}`)
      continue
    }
    const abi = JSON.parse(fs.readFileSync(artifactPath, 'utf8')).abi as Abi
    for (const raw of abi) {
      if (raw.type !== 'error') continue
      const item = raw as AbiErrorItem
      const signature = errorSignature(item)
      const selector = toFunctionSelector(signature)

      const existing = registry[selector]
      if (existing) {
        if (existing.signature !== signature) {
          collisions.push(`${selector}: ${existing.signature} vs ${signature}`)
        }
        if (!existing.sources.includes(contract)) existing.sources.push(contract)
        continue
      }
      registry[selector] = {
        name: item.name,
        signature,
        inputs: item.inputs,
        sources: [contract],
      }
    }
  }

  const sorted = Object.fromEntries(
    Object.entries(registry).sort((a, b) => a[1].signature.localeCompare(b[1].signature)),
  )

  fs.writeFileSync(REGISTRY_PATH, JSON.stringify(sorted, null, 2) + '\n')
  console.log(`Wrote ${Object.keys(sorted).length} unique errors to ${REGISTRY_PATH}`)
  if (collisions.length > 0) {
    console.warn(
      `\n⚠ ${collisions.length} selector collision(s) (same 4 bytes, different signature):`,
    )
    collisions.forEach((c) => console.warn('  ' + c))
  }
}

main()
