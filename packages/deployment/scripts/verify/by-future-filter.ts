import fs from 'fs'
import hre from 'hardhat'
import path, { resolve } from 'path'

/**
 * Verify a subset of an Ignition deployment on the block explorer, selected by futureId substring.
 *
 * Why this exists: `hardhat ignition verify chain-<id>` verifies the WHOLE deployment and aborts if
 * any single execution state has a missing/empty build-info file (e.g. a stale stub committed for an
 * unrelated contract). This script instead reads the deployed addresses, constructor args (from the
 * journal) and contract FQN (from the per-future artifact) and calls `verify:verify` per contract —
 * recompiling from the project sources, so it never reads Ignition's build-info.
 *
 * Usage:
 *   VERIFY_FILTER="Ext_Demo_StdEng_USDC,RoundsVaultRegistry#RoundsVaultRegistry" \
 *     NETWORK=base pnpm verify:by-filter
 *
 * VERIFY_FILTER is a comma-separated list of substrings matched against Ignition futureIds. When
 * omitted it defaults to the Ext_Demo_StdEng_USDC fleet plus the production RoundsVaultRegistry.
 */

// Recompile from the core-contracts sources (matches scripts/verify/buffer-arks.ts) so verify:verify
// can reproduce the deployed bytecode.
const multiSources = [resolve(__dirname, '../../../core-contracts/src')]

const DEFAULT_FILTERS = ['Ext_Demo_StdEng_USDC', 'RoundsVaultRegistry#RoundsVaultRegistry']

async function main() {
  for (const sourcePath of multiSources) {
    hre.config.paths.sources = sourcePath
    hre.config.paths.root = resolve(sourcePath, '..')
  }

  const publicClient = await hre.viem.getPublicClient()
  const chainId = await publicClient.getChainId()
  const deploymentDir = path.join(
    __dirname,
    '..',
    '..',
    'ignition',
    'deployments',
    `chain-${chainId}`,
  )
  if (!fs.existsSync(deploymentDir)) {
    throw new Error(`No Ignition deployment dir for chain ${chainId}: ${deploymentDir}`)
  }

  const addresses = JSON.parse(
    fs.readFileSync(path.join(deploymentDir, 'deployed_addresses.json'), 'utf8'),
  ) as Record<string, string>

  // Map futureId -> deployment-init state (constructorArgs + linked libraries) from the journal.
  const states: Record<
    string,
    { constructorArgs?: unknown[]; libraries?: Record<string, string> }
  > = {}
  for (const line of fs
    .readFileSync(path.join(deploymentDir, 'journal.jsonl'), 'utf8')
    .split('\n')) {
    const trimmed = line.trim()
    if (!trimmed) continue
    let entry: any
    try {
      entry = JSON.parse(trimmed)
    } catch {
      continue
    }
    if (entry.futureId && 'constructorArgs' in entry) {
      states[entry.futureId] = {
        constructorArgs: entry.constructorArgs,
        libraries: entry.libraries,
      }
    }
  }

  const filters = process.env.VERIFY_FILTER
    ? process.env.VERIFY_FILTER.split(',')
        .map((s) => s.trim())
        .filter(Boolean)
    : DEFAULT_FILTERS

  const futureIds = Object.keys(addresses).filter((fid) => filters.some((f) => fid.includes(f)))
  if (futureIds.length === 0) {
    console.log(`No deployed contracts match filter(s): ${filters.join(', ')}`)
    return
  }

  console.log(`Chain ${chainId} — verifying ${futureIds.length} contract(s):`)
  futureIds.forEach((fid) => console.log(`  - ${fid} @ ${addresses[fid]}`))

  let ok = 0
  const failures: string[] = []
  for (const fid of futureIds) {
    const address = addresses[fid]
    const state = states[fid]
    const constructorArguments = (state?.constructorArgs ?? []) as unknown[]
    const libraries =
      state?.libraries && Object.keys(state.libraries).length > 0 ? state.libraries : undefined

    // Fully-qualified name from the per-future artifact emitted by Ignition.
    const artifactPath = path.join(deploymentDir, 'artifacts', `${fid}.json`)
    if (!fs.existsSync(artifactPath)) {
      console.error(`  ✗ ${fid}: artifact not found at ${artifactPath}`)
      failures.push(fid)
      continue
    }
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'))
    const fqn = `${artifact.sourceName}:${artifact.contractName}`

    try {
      console.log(`\nVerifying ${fid} (${fqn}) @ ${address} ...`)
      await hre.run('verify:verify', { address, contract: fqn, constructorArguments, libraries })
      console.log(`  ✓ ${fid}`)
      ok++
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error)
      if (/already verified/i.test(msg)) {
        console.log(`  ✓ ${fid} (already verified)`)
        ok++
      } else {
        console.error(`  ✗ ${fid}: ${msg}`)
        failures.push(fid)
      }
    }
  }

  console.log(`\nDone. ${ok}/${futureIds.length} verified.`)
  if (failures.length > 0) {
    console.log(`Failed: ${failures.join(', ')}`)
    process.exitCode = 1
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error('An error occurred:', error)
    process.exit(1)
  })
}
