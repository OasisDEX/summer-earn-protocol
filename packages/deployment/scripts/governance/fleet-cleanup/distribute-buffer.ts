import fs from 'node:fs'
import path from 'node:path'

import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, encodeFunctionData, getAddress, Hex, parseAbi } from 'viem'

import { HUB_CHAIN_ID, HUB_CHAIN_NAME } from '../../common/constants'
import { ChainName, getChainConfigByChainName } from '../../helpers/chain-configs'
import { ChainSetup } from '../../helpers/chain-prompt'
import { buildCrossChainProposalAction } from '../../helpers/cross-chain-proposal'
import { getChainId } from '../../helpers/get-chainid'
import { promptForConfigType } from '../../helpers/prompt-helpers'
import { createGovernanceProposal } from '../../helpers/proposal-helpers'
import {
  cleanupConfigDir,
  CURATOR_ROLE_ENUM,
  fleetAbi,
  formatAssets,
  pamViewAbi,
  proposalsDir,
  raftViewAbi,
  sanitizeFleetName,
} from './common'

/**
 * Fleet-cleanup STEP 2: sweep the buffer ark's underlying (USDC) to the timelock and distribute
 * it to users via a Merkl campaign — one governance proposal per fleet.
 *
 * Reads config/fleet-cleanup/<network>/distributions.json (see DistributionsConfig below). The
 * Merkl `campaignData` bytes are engine-defined and MUST be generated via Merkl Studio / the
 * Merkl API (the documented DAO flow) and pasted into the config verbatim — this script embeds
 * them, it does not construct them.
 *
 * Per-fleet ordered action list (executed by the fleet-chain timelock; the fleet can stay PAUSED
 * throughout — none of these are whenNotPaused):
 *   1. PAM.grantCuratorRole(fleet, timelock)            — only if needed for setSweepableToken
 *   2. Raft.setSweepableToken(bufferArk, asset, true)   — if not already sweepable
 *   3. Raft.setNonSweepableToken(bufferArk, asset, false) — if governance-blacklisted
 *   4. Raft.socializeLosses(bufferArk, [asset], timelock) — sweeps the FULL buffer balance.
 *      (Ark.sweep's board-asset-back-to-buffer branch is skipped when the ark IS the buffer,
 *      so the underlying transfers out — this is the loss-socialization mechanism.)
 *   5/6. restore the sweepable/blacklist flags to their prior state
 *   7. PAM.revokeCuratorRole(fleet, timelock)           — if granted in 1
 *   8. ERC20(asset).approve(DistributionCreator, amount)
 *   9. DistributionCreator.acceptConditions()           — Merkl T&C gate for contracts; idempotent
 *  10. DistributionCreator.createCampaign({0x0, 0x0, asset, amount, campaignType, start, duration,
 *      campaignData}) — pulls `amount` from the timelock via transferFrom.
 *
 * `amount: "live"` pins the campaign amount to the buffer's CURRENT balance (a paused fleet's
 * buffer is static). Regenerate after any expected inflow (e.g. a claimed async withdrawal).
 *
 * Non-interactive usage:
 *   BUMMER=true|false FLEETS=0x..,0x.. YES=1 LZ_GAS_LIMIT=350000 \
 *     NETWORK=mainnet pnpm gov:cleanup-fleets:distribute
 */

interface DistributionCampaignConfig {
  fleetAddress: Address
  /** "live" = pin to the buffer ark's balance at generation time; otherwise a raw base-unit string */
  amount: 'live' | string
  campaignType: number
  startTimestamp: number
  duration: number
  /** Engine-defined bytes from Merkl Studio / API — embedded verbatim */
  campaignData: Hex
}

interface DistributionsConfig {
  distributionCreator: Address
  campaigns: DistributionCampaignConfig[]
}

const erc20Abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function approve(address spender, uint256 amount) returns (bool)',
])

const merklAbi = parseAbi([
  'function acceptConditions()',
  'function createCampaign((bytes32 campaignId, address creator, address rewardToken, uint256 amount, uint32 campaignType, uint32 startTimestamp, uint32 duration, bytes campaignData) newCampaign) returns (bytes32)',
  'function rewardTokenMinAmounts(address token) view returns (uint256)',
])

const raftWriteAbi = parseAbi([
  'function setSweepableToken(address ark, address token, bool isSweepable)',
  'function setNonSweepableToken(address ark, address token, bool isNonSweepable)',
  'function socializeLosses(address ark, address[] tokens, address receiver)',
])

const pamWriteAbi = parseAbi([
  'function grantCuratorRole(address fleetCommanderAddress, address account)',
  'function revokeCuratorRole(address fleetCommanderAddress, address account)',
])

interface PlannedAction {
  target: Address
  calldata: Hex
  summary: string
}

function fail(message: string): never {
  console.log(kleur.red(`❌ ${message}`))
  process.exit(1)
}

async function main() {
  const network = hre.network.name
  const chainId = getChainId()
  console.log(kleur.blue('Network:'), kleur.cyan(`${network} (chainId ${chainId})`))

  const useBummerConfig =
    process.env.BUMMER !== undefined ? process.env.BUMMER === 'true' : await promptForConfigType()

  const fleetChainSetup: ChainSetup = {
    name: network as ChainName,
    ...getChainConfigByChainName(network as ChainName, useBummerConfig),
  }
  const dc = fleetChainSetup.config.deployedContracts
  const raftAddress = getAddress(dc.core.raft.address)
  const pamAddress = getAddress(dc.gov.protocolAccessManager.address)
  const timelock = getAddress(dc.govV2.timelock.address)

  const hubSetup = getChainConfigByChainName(HUB_CHAIN_NAME as ChainName, useBummerConfig)
  const hubGovernor = getAddress(hubSetup.config.deployedContracts.govV2.summerGovernor.address)
  const fleetIsHub = network === HUB_CHAIN_NAME
  const lzGasLimit = process.env.LZ_GAS_LIMIT ? BigInt(process.env.LZ_GAS_LIMIT) : 350000n

  const publicClient = await hre.viem.getPublicClient()

  // ---- Load distributions config ----
  const cfgFile = path.join(cleanupConfigDir(network), 'distributions.json')
  if (!fs.existsSync(cfgFile)) {
    fail(`No distributions config at ${cfgFile} — create it first (see script header for shape).`)
  }
  const distConfig = JSON.parse(fs.readFileSync(cfgFile, 'utf8')) as DistributionsConfig
  const distributionCreator = getAddress(distConfig.distributionCreator)

  const fleetFilter = process.env.FLEETS
    ? new Set(process.env.FLEETS.split(',').map((a) => getAddress(a.trim())))
    : null
  const campaigns = distConfig.campaigns.filter(
    (c) => !fleetFilter || fleetFilter.has(getAddress(c.fleetAddress)),
  )
  if (campaigns.length === 0) {
    console.log(kleur.yellow('No campaigns selected — nothing to do.'))
    return
  }

  // Timelock must hold GOVERNOR_ROLE on this chain's PAM
  const governorRole = await publicClient.readContract({
    address: pamAddress,
    abi: pamViewAbi,
    functionName: 'GOVERNOR_ROLE',
  })
  const isGov = await publicClient.readContract({
    address: pamAddress,
    abi: pamViewAbi,
    functionName: 'hasRole',
    args: [governorRole, timelock],
  })
  if (!isGov) fail(`Timelock ${timelock} does not hold GOVERNOR_ROLE on PAM ${pamAddress}.`)
  console.log(kleur.green(`✓ timelock ${timelock} holds GOVERNOR_ROLE`))

  // ---- Validate each campaign against live chain state and build its plan ----
  interface FleetPlan {
    cfg: DistributionCampaignConfig
    fleetName: string
    bufferArk: Address
    asset: Address
    assetSymbol: string
    assetDecimals: number
    bufferBalance: bigint
    amount: bigint
    isSweepable: boolean
    isNonSweepable: boolean
    timelockHasCurator: boolean
    actions: PlannedAction[]
  }
  const plans: FleetPlan[] = []

  const nowSec = Math.floor(Date.now() / 1000)
  for (const cfg of campaigns) {
    const fleet = getAddress(cfg.fleetAddress)
    const [fleetName, bufferArkRaw, assetRaw, paused] = await Promise.all([
      publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'name' }),
      publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'bufferArk' }),
      publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'asset' }),
      publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'paused' }),
    ])
    const bufferArk = getAddress(bufferArkRaw as string)
    const asset = getAddress(assetRaw as string)
    console.log(kleur.blue(`\nValidating ${fleetName} (${fleet})…`))

    const [assetSymbol, assetDecimals, bufferBalance] = await Promise.all([
      publicClient.readContract({ address: asset, abi: erc20Abi, functionName: 'symbol' }),
      publicClient.readContract({ address: asset, abi: erc20Abi, functionName: 'decimals' }),
      publicClient.readContract({
        address: asset,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [bufferArk],
      }),
    ])

    if (!paused) {
      console.log(
        kleur.yellow(
          `  ⚠ ${fleetName} is NOT paused — the buffer balance can change before execution; ` +
            `a pinned amount may end up exceeding the swept balance (createCampaign would revert the batch).`,
        ),
      )
    }

    const amount = cfg.amount === 'live' ? bufferBalance : BigInt(cfg.amount)
    if (amount === 0n) {
      fail(
        `${fleetName}: campaign amount is 0 (buffer balance ${bufferBalance}) — nothing to distribute.`,
      )
    }
    if (amount > bufferBalance) {
      fail(
        `${fleetName}: pinned amount ${amount} exceeds live buffer balance ${bufferBalance} — ` +
          `regenerate after the expected inflow lands (or lower the amount).`,
      )
    }
    if (!/^0x[0-9a-fA-F]+$/.test(cfg.campaignData) || cfg.campaignData.length < 10) {
      fail(
        `${fleetName}: campaignData looks invalid (${cfg.campaignData.slice(0, 20)}…) — paste the ` +
          `bytes generated by Merkl Studio / the Merkl API.`,
      )
    }
    if (cfg.startTimestamp <= nowSec) {
      fail(
        `${fleetName}: startTimestamp ${cfg.startTimestamp} is in the past — the campaign must start ` +
          `after the proposal executes (vote + timelock + LayerZero ≈ days; pick a comfortable buffer).`,
      )
    }
    if (cfg.duration <= 0) fail(`${fleetName}: duration must be > 0 seconds.`)

    // Merkl-side sanity: reward token must be whitelisted with a min hourly amount
    const minAmount = await publicClient.readContract({
      address: distributionCreator,
      abi: merklAbi,
      functionName: 'rewardTokenMinAmounts',
      args: [asset],
    })
    if (minAmount === 0n) {
      fail(`${fleetName}: ${assetSymbol} is not whitelisted as a Merkl reward token on ${network}.`)
    }
    if (amount * 3600n < minAmount * BigInt(cfg.duration)) {
      fail(
        `${fleetName}: amount ${amount} over ${cfg.duration}s is below Merkl's minimum ` +
          `(${minAmount}/hour for ${assetSymbol}).`,
      )
    }

    const [isSweepable, isNonSweepable, timelockHasCurator] = await Promise.all([
      publicClient.readContract({
        address: raftAddress,
        abi: raftViewAbi,
        functionName: 'sweepableTokens',
        args: [bufferArk, asset],
      }),
      publicClient.readContract({
        address: raftAddress,
        abi: raftViewAbi,
        functionName: 'nonSweepableTokens',
        args: [bufferArk, asset],
      }),
      (async () => {
        const curatorRole = await publicClient.readContract({
          address: pamAddress,
          abi: pamViewAbi,
          functionName: 'generateRole',
          args: [CURATOR_ROLE_ENUM, fleet],
        })
        return publicClient.readContract({
          address: pamAddress,
          abi: pamViewAbi,
          functionName: 'hasRole',
          args: [curatorRole, timelock],
        })
      })(),
    ])

    // ---- Ordered actions ----
    const actions: PlannedAction[] = []
    const grantCurator = !isSweepable && !timelockHasCurator
    if (grantCurator) {
      actions.push({
        target: pamAddress,
        calldata: encodeFunctionData({
          abi: pamWriteAbi,
          functionName: 'grantCuratorRole',
          args: [fleet, timelock],
        }),
        summary: `PAM.grantCuratorRole(${fleetName}, timelock) — temporary, for setSweepableToken`,
      })
    }
    if (!isSweepable) {
      actions.push({
        target: raftAddress,
        calldata: encodeFunctionData({
          abi: raftWriteAbi,
          functionName: 'setSweepableToken',
          args: [bufferArk, asset, true],
        }),
        summary: `Raft.setSweepableToken(bufferArk, ${assetSymbol}, true)`,
      })
    }
    if (isNonSweepable) {
      actions.push({
        target: raftAddress,
        calldata: encodeFunctionData({
          abi: raftWriteAbi,
          functionName: 'setNonSweepableToken',
          args: [bufferArk, asset, false],
        }),
        summary: `Raft.setNonSweepableToken(bufferArk, ${assetSymbol}, false) — lift blacklist`,
      })
    }
    actions.push({
      target: raftAddress,
      calldata: encodeFunctionData({
        abi: raftWriteAbi,
        functionName: 'socializeLosses',
        args: [bufferArk, [asset], timelock],
      }),
      summary: `Raft.socializeLosses(bufferArk, [${assetSymbol}], timelock) — sweeps ${formatAssets(bufferBalance, assetDecimals, assetSymbol)}`,
    })
    if (isNonSweepable) {
      actions.push({
        target: raftAddress,
        calldata: encodeFunctionData({
          abi: raftWriteAbi,
          functionName: 'setNonSweepableToken',
          args: [bufferArk, asset, true],
        }),
        summary: `Raft.setNonSweepableToken(bufferArk, ${assetSymbol}, true) — restore blacklist`,
      })
    }
    if (!isSweepable) {
      actions.push({
        target: raftAddress,
        calldata: encodeFunctionData({
          abi: raftWriteAbi,
          functionName: 'setSweepableToken',
          args: [bufferArk, asset, false],
        }),
        summary: `Raft.setSweepableToken(bufferArk, ${assetSymbol}, false) — restore whitelist`,
      })
    }
    if (grantCurator) {
      actions.push({
        target: pamAddress,
        calldata: encodeFunctionData({
          abi: pamWriteAbi,
          functionName: 'revokeCuratorRole',
          args: [fleet, timelock],
        }),
        summary: `PAM.revokeCuratorRole(${fleetName}, timelock) — cleanup`,
      })
    }
    actions.push({
      target: asset,
      calldata: encodeFunctionData({
        abi: erc20Abi,
        functionName: 'approve',
        args: [distributionCreator, amount],
      }),
      summary: `${assetSymbol}.approve(DistributionCreator, ${formatAssets(amount, assetDecimals, assetSymbol)})`,
    })
    actions.push({
      target: distributionCreator,
      calldata: encodeFunctionData({ abi: merklAbi, functionName: 'acceptConditions' }),
      summary: `DistributionCreator.acceptConditions() — Merkl T&C (idempotent)`,
    })
    actions.push({
      target: distributionCreator,
      calldata: encodeFunctionData({
        abi: merklAbi,
        functionName: 'createCampaign',
        args: [
          {
            campaignId: '0x0000000000000000000000000000000000000000000000000000000000000000',
            creator: '0x0000000000000000000000000000000000000000',
            rewardToken: asset,
            amount,
            campaignType: cfg.campaignType,
            startTimestamp: cfg.startTimestamp,
            duration: cfg.duration,
            campaignData: cfg.campaignData,
          },
        ],
      }),
      summary:
        `DistributionCreator.createCampaign(type ${cfg.campaignType}, ` +
        `${formatAssets(amount, assetDecimals, assetSymbol)}, start ${new Date(cfg.startTimestamp * 1000).toISOString()}, ` +
        `duration ${cfg.duration}s) — pulls the amount via transferFrom`,
    })

    plans.push({
      cfg,
      fleetName,
      bufferArk: getAddress(bufferArk),
      asset: getAddress(asset),
      assetSymbol,
      assetDecimals,
      bufferBalance,
      amount,
      isSweepable,
      isNonSweepable,
      timelockHasCurator,
      actions,
    })
  }

  // ---- Summary ----
  console.log(kleur.cyan().bold('\n================ Distribution plan ================'))
  for (const p of plans) {
    console.log(kleur.yellow(`\nFleet ${p.fleetName} (${p.cfg.fleetAddress})`))
    console.log(
      `  buffer balance : ${formatAssets(p.bufferBalance, p.assetDecimals, p.assetSymbol)}`,
    )
    console.log(
      kleur.red(
        `  distribute     : ${formatAssets(p.amount, p.assetDecimals, p.assetSymbol)} via Merkl campaign ` +
          `(type ${p.cfg.campaignType}; Merkl fee comes out of this gross amount)`,
      ),
    )
    console.log(`  raft flags     : sweepable=${p.isSweepable} nonSweepable=${p.isNonSweepable}`)
    p.actions.forEach((a, i) => console.log(kleur.yellow(`  ${i + 1}. ${a.summary}`)))
  }
  console.log(
    kleur
      .red()
      .bold(
        `\n⚠️  Sweeping the buffer removes the assets backing the fleet's shares — share price drops ` +
          `accordingly. The Merkl campaign is the compensation path for holders.`,
      ),
  )

  if (process.env.YES !== '1') {
    const { confirmed } = await prompts({
      type: 'confirm',
      name: 'confirmed',
      message: `Build ${plans.length} governance proposal(s) for this plan?`,
      initial: false,
    })
    if (!confirmed) {
      console.log(kleur.red('Operation cancelled by user.'))
      return
    }
  }

  // ---- Emit one proposal per fleet ----
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const prefix = useBummerConfig ? 'test' : 'prod'
  const writtenFiles: string[] = []

  for (const p of plans) {
    const description =
      `# Fleet distribution — ${p.fleetName}\n\n` +
      (fleetIsHub
        ? `Executed on the ${HUB_CHAIN_NAME} hub by the timelock ${timelock}.`
        : `Created on the ${HUB_CHAIN_NAME} hub and relayed via LayerZero to the ${network} timelock ${timelock} for execution.`) +
      `\n\nSweeps ${formatAssets(p.amount, p.assetDecimals, p.assetSymbol)} from the buffer ark ` +
      `${p.bufferArk} to the timelock and creates a Merkl campaign (type ${p.cfg.campaignType}) ` +
      `distributing it to fleet users. The fleet remains paused throughout.\n\n## Actions\n` +
      p.actions.map((a, i) => `${i + 1}. ${a.summary}`).join('\n')

    const dstActions = p.actions.map((a) => ({ target: a.target, value: 0n, calldata: a.calldata }))
    let srcActions: { target: Address; value: bigint; calldata: Hex }[]
    let crossChainExecution:
      | { name: string; chainId: number; targets: string[]; values: string[]; datas: string[] }[]
      | undefined

    if (fleetIsHub) {
      srcActions = dstActions
    } else {
      const hubAction = await buildCrossChainProposalAction({
        targetChain: fleetChainSetup,
        targets: dstActions.map((a) => a.target),
        values: dstActions.map((a) => a.value),
        calldatas: dstActions.map((a) => a.calldata),
        description,
        governorAddress: hubGovernor,
        gasLimit: lzGasLimit,
      })
      srcActions = [hubAction]
      crossChainExecution = [
        {
          name: fleetChainSetup.name,
          chainId,
          targets: dstActions.map((a) => a.target as string),
          values: dstActions.map((a) => a.value.toString()),
          datas: dstActions.map((a) => a.calldata as string),
        },
      ]
    }

    const savePath = path.join(
      proposalsDir(),
      `${prefix}_fleet_distribution_proposal_${sanitizeFleetName(p.fleetName)}_${network}_${timestamp}.json`,
    )
    await createGovernanceProposal(
      `Fleet distribution — ${p.fleetName} (${network})`,
      description,
      srcActions,
      hubGovernor,
      HUB_CHAIN_ID,
      '',
      p.actions.map((a) => a.summary),
      savePath,
      crossChainExecution,
    )
    writtenFiles.push(savePath)
  }

  console.log(kleur.green().bold(`\n✅ ${writtenFiles.length} proposal file(s) written:`))
  for (const f of writtenFiles) console.log(kleur.green(`   ${f}`))
  console.log(
    kleur.cyan(
      `\nSubmit each proposal on the ${HUB_CHAIN_NAME} hub with: NETWORK=${HUB_CHAIN_NAME} pnpm gov:submit-proposal.`,
    ),
  )
  if (!fleetIsHub) {
    console.log(
      kleur.yellow(
        `⚠️  Cross-chain: the ${HUB_CHAIN_NAME} hub governor ${hubGovernor} must hold native gas for the ` +
          `LayerZero fee when sendProposalToTargetChain executes.`,
      ),
    )
  }
  console.log(
    kleur.gray(
      '\nPrerequisites before execution: the airdrop JSON must be hosted at the URL baked into ' +
        'campaignData, and the campaign startTimestamp must still be in the future when the ' +
        'proposal executes on the satellite.',
    ),
  )
}

main().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
