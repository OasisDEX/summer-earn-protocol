import fs from 'node:fs'
import path from 'node:path'

import hre from 'hardhat'
import kleur from 'kleur'
import { Address, getAddress } from 'viem'

import { BaseConfig } from '../../../types/config-types'
import { getConfigByNetwork } from '../../helpers/config-handler'
import { getChainId } from '../../helpers/get-chainid'
import { promptForConfigType } from '../../helpers/prompt-helpers'
import {
  arkAbi,
  CleanupArkEntry,
  cleanupConfigDir,
  erc20Abi,
  fleetAbi,
  FleetCleanupConfig,
  formatAssets,
  formatCap,
  harborCommandAbi,
  parseDetailsJson,
  sanitizeFleetName,
} from './common'

/**
 * Generates one editable fleet-cleanup JSON per fleet into config/fleet-cleanup/<network>/.
 *
 * Every ark (buffer ark included, flagged) is listed with its live totalAssets / depositCap /
 * details().pool and a default `action: "leave"`. The operator edits actions (and the fleet's
 * `repauseAfter` flag), then runs `gov:cleanup-fleets` to emit Safe batches.
 *
 * Existing files are NEVER overwritten unless FORCE=1 — they may carry hand-edited actions.
 *
 * Non-interactive usage (all optional, prompts otherwise):
 *   BUMMER=true|false FLEETS=0x..,0x.. FORCE=1 NETWORK=mainnet pnpm gov:cleanup-fleets:init
 */

async function main() {
  const network = hre.network.name
  const chainId = getChainId()
  console.log(kleur.blue('Network:'), kleur.cyan(`${network} (chainId ${chainId})`))

  const useBummerConfig =
    process.env.BUMMER !== undefined ? process.env.BUMMER === 'true' : await promptForConfigType()

  const config = getConfigByNetwork(
    network,
    { common: true, core: true },
    useBummerConfig,
  ) as BaseConfig

  const harborCommandAddress = getAddress(config.deployedContracts.core.harborCommand.address)
  const publicClient = await hre.viem.getPublicClient()

  const fleetFilter = process.env.FLEETS
    ? new Set(process.env.FLEETS.split(',').map((a) => getAddress(a.trim())))
    : null
  const force = process.env.FORCE === '1'

  const allFleets = (
    await publicClient.readContract({
      address: harborCommandAddress,
      abi: harborCommandAbi,
      functionName: 'getActiveFleetCommanders',
    })
  ).map((a) => getAddress(a))

  const fleets = fleetFilter ? allFleets.filter((f) => fleetFilter.has(f)) : allFleets
  console.log(
    kleur.blue(`HarborCommand ${harborCommandAddress}:`),
    kleur.cyan(
      `${allFleets.length} active fleet(s)${fleetFilter ? `, ${fleets.length} after FLEETS filter` : ''}`,
    ),
  )

  const outDir = cleanupConfigDir(network)
  fs.mkdirSync(outDir, { recursive: true })

  for (const fleetAddress of fleets) {
    const [
      fleetName,
      activeArks,
      bufferArk,
      paused,
      pauseStartTime,
      minimumPauseTime,
      asset,
      fleetTotalAssets,
    ] = await Promise.all([
      publicClient.readContract({ address: fleetAddress, abi: fleetAbi, functionName: 'name' }),
      publicClient.readContract({
        address: fleetAddress,
        abi: fleetAbi,
        functionName: 'getActiveArks',
      }),
      publicClient.readContract({
        address: fleetAddress,
        abi: fleetAbi,
        functionName: 'bufferArk',
      }),
      publicClient.readContract({ address: fleetAddress, abi: fleetAbi, functionName: 'paused' }),
      publicClient.readContract({
        address: fleetAddress,
        abi: fleetAbi,
        functionName: 'pauseStartTime',
      }),
      publicClient.readContract({
        address: fleetAddress,
        abi: fleetAbi,
        functionName: 'minimumPauseTime',
      }),
      publicClient.readContract({ address: fleetAddress, abi: fleetAbi, functionName: 'asset' }),
      publicClient.readContract({
        address: fleetAddress,
        abi: fleetAbi,
        functionName: 'totalAssets',
      }),
    ])

    const outFile = path.join(outDir, `${sanitizeFleetName(fleetName)}.json`)
    if (fs.existsSync(outFile) && !force) {
      console.log(
        kleur.yellow(
          `⚠ ${path.basename(outFile)} already exists — skipping (may carry hand edits; FORCE=1 to overwrite).`,
        ),
      )
      continue
    }

    const [assetSymbol, assetDecimals] = await Promise.all([
      publicClient.readContract({ address: asset, abi: erc20Abi, functionName: 'symbol' }),
      publicClient.readContract({ address: asset, abi: erc20Abi, functionName: 'decimals' }),
    ])

    console.log(
      kleur.blue(`\nFleet ${fleetName} (${fleetAddress})`),
      kleur.cyan(
        `— ${activeArks.length} active arks + buffer, TVL ${formatAssets(fleetTotalAssets, assetDecimals, assetSymbol)}`,
      ),
    )

    const arkEntries: CleanupArkEntry[] = []
    const allArks: { address: Address; isBufferArk: boolean }[] = [
      ...activeArks.map((a) => ({ address: getAddress(a), isBufferArk: false })),
      { address: getAddress(bufferArk), isBufferArk: true },
    ]

    for (const { address: arkAddress, isBufferArk } of allArks) {
      const [name, totalAssets, depositCap, detailsJson] = await Promise.all([
        publicClient.readContract({ address: arkAddress, abi: arkAbi, functionName: 'name' }),
        publicClient.readContract({
          address: arkAddress,
          abi: arkAbi,
          functionName: 'totalAssets',
        }),
        publicClient.readContract({ address: arkAddress, abi: arkAbi, functionName: 'depositCap' }),
        publicClient.readContract({ address: arkAddress, abi: arkAbi, functionName: 'details' }),
      ])
      const { protocol, pool } = parseDetailsJson(detailsJson)
      arkEntries.push({
        name,
        address: arkAddress,
        isBufferArk,
        totalAssets: totalAssets.toString(),
        totalAssetsFormatted: formatAssets(totalAssets, assetDecimals, assetSymbol),
        depositCap: depositCap.toString(),
        depositCapFormatted: formatCap(depositCap, assetDecimals, assetSymbol),
        protocol,
        pool,
        action: 'leave',
      })
    }

    const fleetConfig: FleetCleanupConfig = {
      network,
      chainId,
      configType: useBummerConfig ? 'test' : 'prod',
      generatedAt: new Date().toISOString(),
      fleetName,
      fleetAddress,
      bufferArk: getAddress(bufferArk),
      asset: getAddress(asset),
      assetSymbol,
      assetDecimals,
      fleetTotalAssets: fleetTotalAssets.toString(),
      fleetTotalAssetsFormatted: formatAssets(fleetTotalAssets, assetDecimals, assetSymbol),
      paused,
      unpauseNotBefore: paused
        ? new Date(Number(pauseStartTime + minimumPauseTime) * 1000).toISOString()
        : null,
      repauseAfter: false,
      arks: arkEntries,
    }

    fs.writeFileSync(outFile, JSON.stringify(fleetConfig, null, 2) + '\n')
    console.log(kleur.green(`✓ wrote ${outFile}`))
  }

  console.log(
    kleur.cyan(
      `\nDone. Edit the per-ark "action" fields (${'leave | socializeLosses | socializeLossesAndRemove | removeArk'}) ` +
        `and the fleet-level "repauseAfter" flag, then run: NETWORK=${network} pnpm gov:cleanup-fleets`,
    ),
  )
}

main().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
