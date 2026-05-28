/**
 * read-lz-config.ts
 *
 * Reads on-chain LayerZero ULN configuration for all OApps (SummerToken,
 * SummerGovernorV1, SummerGovernorV2) across all supported chains and prints a
 * diagnostic summary.
 *
 * Usage:
 *   npx hardhat run scripts/bridge/read-lz-config.ts --network base [-- --bummer]
 */

import kleur from 'kleur'
import { Address, decodeAbiParameters, type PublicClient } from 'viem'
import { BaseConfig, SupportedNetworks } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getChainPublicClient } from '../helpers/client-by-chain-helper'
import { getConfigByNetwork } from '../helpers/config-handler'
import { LZ_ENDPOINT_ABI } from '../governance/bridge/lz-endpoint-abi'

// ---------------------------------------------------------------------------
// Inline ABI for OApp.peers() — not imported from contracts directly
// ---------------------------------------------------------------------------
const PEERS_ABI = [
  {
    name: 'peers',
    type: 'function',
    inputs: [{ name: '', type: 'uint32' }],
    outputs: [{ name: '', type: 'bytes32' }],
    stateMutability: 'view',
  },
] as const

// ---------------------------------------------------------------------------
// ULN config ABI parameters (configType = 2)
// ---------------------------------------------------------------------------
const ULN_CONFIG_ABI_PARAMS = [
  {
    type: 'tuple',
    components: [
      { name: 'confirmations', type: 'uint64' },
      { name: 'requiredDVNCount', type: 'uint8' },
      { name: 'optionalDVNCount', type: 'uint8' },
      { name: 'optionalDVNThreshold', type: 'uint8' },
      { name: 'requiredDVNs', type: 'address[]' },
      { name: 'optionalDVNs', type: 'address[]' },
    ],
  },
] as const

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------
interface UlnConfig {
  confirmations: bigint
  requiredDVNCount: number
  optionalDVNCount: number
  optionalDVNThreshold: number
  requiredDVNs: readonly string[]
  optionalDVNs: readonly string[]
}

interface RouteInfo {
  chain: string
  remoteChain: string
  oAppName: string
  oAppAddress: string
  peer: string | null // null = call failed
  sendUln: UlnConfig | null
  receiveUln: UlnConfig | null
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const ZERO_BYTES32 = '0x' + '0'.repeat(64)

function isZeroBytes32(value: string): boolean {
  return value === ZERO_BYTES32 || value === '0x' + '0'.repeat(64)
}

function formatUlnConfig(cfg: UlnConfig): string {
  const reqDvns = [...cfg.requiredDVNs].sort().join(', ')
  const optDvns = [...cfg.optionalDVNs].sort().join(', ')
  return (
    `confirmations=${cfg.confirmations}, ` +
    `requiredDVNs(${cfg.requiredDVNCount})=[${reqDvns}], ` +
    `optionalDVNs(${cfg.optionalDVNCount}, threshold=${cfg.optionalDVNThreshold})=[${optDvns}]`
  )
}

async function readPeer(
  client: PublicClient,
  oAppAddr: Address,
  remoteEid: number,
): Promise<string> {
  try {
    const result = await client.readContract({
      address: oAppAddr,
      abi: PEERS_ABI,
      functionName: 'peers',
      args: [remoteEid],
    })
    return result as string
  } catch {
    return ZERO_BYTES32
  }
}

async function readUlnConfig(
  client: PublicClient,
  endpointAddr: Address,
  oAppAddr: Address,
  libAddr: Address,
  remoteEid: number,
): Promise<UlnConfig | null> {
  let raw: string
  try {
    raw = (await client.readContract({
      address: endpointAddr,
      abi: LZ_ENDPOINT_ABI,
      functionName: 'getConfig',
      args: [oAppAddr, libAddr, remoteEid, 2],
    })) as string
  } catch {
    return null
  }

  if (!raw || raw === '0x') {
    return null
  }

  try {
    const [decoded] = decodeAbiParameters(ULN_CONFIG_ABI_PARAMS, raw as `0x${string}`)
    return {
      confirmations: decoded.confirmations,
      requiredDVNCount: decoded.requiredDVNCount,
      optionalDVNCount: decoded.optionalDVNCount,
      optionalDVNThreshold: decoded.optionalDVNThreshold,
      requiredDVNs: decoded.requiredDVNs,
      optionalDVNs: decoded.optionalDVNs,
    }
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const useBummerConfig = process.argv.includes('--bummer')

  console.log(kleur.cyan().bold('\n=== LayerZero On-Chain ULN Config Diagnostic ==='))
  if (useBummerConfig) {
    console.log(kleur.yellow().bold('Using bummer (test) config'))
  }
  console.log()

  const allChains = Object.values(SupportedNetworks)

  // Load configs for all chains first (skip chains with no LZ endpoint)
  interface ChainEntry {
    chain: string
    config: BaseConfig
    client: PublicClient
  }

  const chainEntries: ChainEntry[] = []

  for (const chain of allChains) {
    let config: BaseConfig
    try {
      config = getConfigByNetwork(chain, { common: true, gov: true }, useBummerConfig) as BaseConfig
    } catch (err) {
      console.log(
        kleur.yellow(`[WARN] Could not load config for ${chain}: ${(err as Error).message}`),
      )
      continue
    }

    const lzEndpoint = config.common?.layerZero?.lzEndpoint
    if (!lzEndpoint || lzEndpoint === ADDRESS_ZERO) {
      console.log(kleur.yellow(`[SKIP] ${chain}: no LZ endpoint configured`))
      continue
    }

    let client: PublicClient
    try {
      client = (await getChainPublicClient(chain)) as PublicClient
    } catch (err) {
      console.log(
        kleur.yellow(
          `[WARN] Could not create public client for ${chain}: ${(err as Error).message}`,
        ),
      )
      continue
    }

    chainEntries.push({ chain, config, client })
  }

  // Collect all route results
  const allRoutes: RouteInfo[] = []

  // Process each chain
  for (const { chain, config, client } of chainEntries) {
    console.log(kleur.bold().white(`\n${'='.repeat(60)}`))
    console.log(kleur.bold().white(`=== ${chain.toUpperCase()} ===`))
    console.log(kleur.bold().white(`${'='.repeat(60)}`))

    const endpointAddr = config.common.layerZero.lzEndpoint as Address
    const sendUln = config.common.layerZero.sendUln302 as Address
    const receiveUln = config.common.layerZero.receiveUln302 as Address

    // Collect OApps for this chain
    const oApps: Array<{ name: string; address: string }> = []

    const summerTokenAddr = config.deployedContracts?.gov?.summerToken?.address
    if (summerTokenAddr && summerTokenAddr !== ADDRESS_ZERO) {
      oApps.push({ name: 'SummerToken', address: summerTokenAddr })
    }

    const govV1Addr = config.deployedContracts?.gov?.summerGovernor?.address
    if (govV1Addr && govV1Addr !== ADDRESS_ZERO) {
      oApps.push({ name: 'SummerGovernorV1', address: govV1Addr })
    }

    const govV2Addr = config.deployedContracts?.govV2?.summerGovernor?.address
    if (govV2Addr && govV2Addr !== ADDRESS_ZERO) {
      oApps.push({ name: 'SummerGovernorV2', address: govV2Addr })
    }

    if (oApps.length === 0) {
      console.log(kleur.yellow('  No OApps found for this chain, skipping.'))
      continue
    }

    // For each OApp × each remote chain
    for (const oApp of oApps) {
      console.log(kleur.bold().blue(`\n  OApp: ${oApp.name} (${oApp.address})`))

      for (const { chain: remoteChain, config: remoteConfig } of chainEntries) {
        if (remoteChain === chain) continue

        const remoteEid = Number(remoteConfig.common.layerZero.eID)
        console.log(kleur.dim(`\n    → Remote: ${remoteChain} (eID=${remoteEid})`))

        const oAppAddr = oApp.address as Address

        // Read peer
        const peer = await readPeer(client, oAppAddr, remoteEid)
        const peerIsSet = !isZeroBytes32(peer)
        if (peerIsSet) {
          console.log(`      Peer:        ${kleur.green(peer)}`)
        } else {
          console.log(`      Peer:        ${kleur.red(peer)} (ZERO — not set)`)
        }

        // Read send ULN config
        const sendUlnConfig = await readUlnConfig(
          client,
          endpointAddr,
          oAppAddr,
          sendUln,
          remoteEid,
        )
        if (sendUlnConfig) {
          console.log(`      Send ULN:    ${kleur.cyan(formatUlnConfig(sendUlnConfig))}`)
        } else {
          console.log(`      Send ULN:    ${kleur.yellow('NOT SET (using endpoint defaults)')}`)
        }

        // Read receive ULN config
        const receiveUlnConfig = await readUlnConfig(
          client,
          endpointAddr,
          oAppAddr,
          receiveUln,
          remoteEid,
        )
        if (receiveUlnConfig) {
          console.log(`      Receive ULN: ${kleur.cyan(formatUlnConfig(receiveUlnConfig))}`)
        } else {
          console.log(`      Receive ULN: ${kleur.yellow('NOT SET (using endpoint defaults)')}`)
        }

        allRoutes.push({
          chain,
          remoteChain,
          oAppName: oApp.name,
          oAppAddress: oApp.address,
          peer: peerIsSet ? peer : null,
          sendUln: sendUlnConfig,
          receiveUln: receiveUlnConfig,
        })
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------------
  console.log(kleur.bold().white(`\n${'='.repeat(60)}`))
  console.log(kleur.bold().white('=== SUMMARY ==='))
  console.log(kleur.bold().white(`${'='.repeat(60)}`))

  const noSendConfig = allRoutes.filter((r) => r.sendUln === null)
  const noReceiveConfig = allRoutes.filter((r) => r.receiveUln === null)
  const noPeer = allRoutes.filter((r) => r.peer === null)

  console.log(
    kleur.bold().yellow(`\nRoutes with NO explicit send ULN config (${noSendConfig.length}):`),
  )
  if (noSendConfig.length === 0) {
    console.log(kleur.green('  (none)'))
  } else {
    for (const r of noSendConfig) {
      console.log(
        kleur.yellow(`  ${r.chain} -> ${r.remoteChain}  [${r.oAppName}]  oApp=${r.oAppAddress}`),
      )
    }
  }

  console.log(
    kleur
      .bold()
      .yellow(`\nRoutes with NO explicit receive ULN config (${noReceiveConfig.length}):`),
  )
  if (noReceiveConfig.length === 0) {
    console.log(kleur.green('  (none)'))
  } else {
    for (const r of noReceiveConfig) {
      console.log(
        kleur.yellow(`  ${r.chain} -> ${r.remoteChain}  [${r.oAppName}]  oApp=${r.oAppAddress}`),
      )
    }
  }

  console.log(kleur.bold().red(`\nRoutes with NO peer set (${noPeer.length}):`))
  if (noPeer.length === 0) {
    console.log(kleur.green('  (none)'))
  } else {
    for (const r of noPeer) {
      console.log(
        kleur.red(`  ${r.chain} -> ${r.remoteChain}  [${r.oAppName}]  oApp=${r.oAppAddress}`),
      )
    }
  }

  console.log()
}

// Handle script execution
main()
  .then(() => {
    console.log(kleur.green().bold('Done.'))
    process.exit(0)
  })
  .catch((err) => {
    console.error(kleur.red().bold('Script failed:'))
    console.error(err)
    process.exit(1)
  })
