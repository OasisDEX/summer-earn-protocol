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
 * Fleet-cleanup STEP 2: sweep the buffer arks' underlying (USDC) of one or MORE fleets to the
 * timelock and distribute the combined amount to users via a single Merkl campaign — one
 * governance proposal per configured campaign.
 *
 * Reads config/fleet-cleanup/<network>/distributions.json. A campaign lists `sweepFleets` (all
 * must share the same underlying asset); the swept balances land in one basket at the timelock
 * and fund ONE createCampaign. Per-fleet/per-user allocation happens OFF-CHAIN in the airdrop
 * JSON (Merkl type-4), where the `reason` field distinguishes e.g. hr vs lr entitlements.
 *
 * The Merkl `campaignData` bytes are engine-defined and MUST be generated via Merkl Studio / the
 * Merkl API (the documented DAO flow) and pasted into the config verbatim — this script embeds
 * them, it does not construct them.
 *
 * Ordered action list (executed by the fleet-chain timelock; fleets can stay PAUSED throughout —
 * none of these are whenNotPaused):
 *   per fleet:
 *     1. PAM.grantCuratorRole(fleet, timelock)              — only if needed for setSweepableToken
 *     2. Raft.setSweepableToken(bufferArk, asset, true)     — if not already sweepable
 *     3. Raft.setNonSweepableToken(bufferArk, asset, false) — if governance-blacklisted
 *     4. Raft.socializeLosses(bufferArk, [asset], timelock) — sweeps the FULL buffer balance.
 *        (Ark.sweep's board-asset-back-to-buffer branch is skipped when the ark IS the buffer,
 *        so the underlying transfers out — this is the loss-socialization mechanism.)
 *     5/6. restore the sweepable/blacklist flags to their prior state
 *     7. PAM.revokeCuratorRole(fleet, timelock)             — if granted in 1
 *   then once:
 *     8. ERC20(asset).approve(DistributionCreator, amount)
 *     9. DistributionCreator.acceptConditions()             — Merkl T&C gate for contracts; idempotent
 *    10. DistributionCreator.createCampaign({0x0, 0x0, asset, amount, campaignType, start,
 *        duration, campaignData}) — pulls `amount` from the timelock via transferFrom.
 *
 * `amount: "live"` pins the campaign amount to the SUM of the buffers' CURRENT balances (a
 * paused fleet's buffer is static). NOTE Merkl's type-4 fee (0.5%) is added ON TOP of the JSON
 * allocations — the airdrop JSON must sum to amount / 1.005, not to the full amount.
 *
 * Non-interactive usage:
 *   BUMMER=true|false FLEETS=0x..,0x.. YES=1 LZ_GAS_LIMIT=350000 \
 *     NETWORK=mainnet pnpm gov:cleanup-fleets:distribute
 */

interface DistributionCampaignConfig {
  /** Display/file name for the campaign & proposal */
  name: string
  /** Buffer arks of ALL these fleets are swept into the timelock; must share the same asset */
  sweepFleets: Address[]
  /** "live" = pin to the SUM of the buffers' balances at generation time; otherwise raw base units */
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
    (c) => !fleetFilter || c.sweepFleets.some((f) => fleetFilter.has(getAddress(f))),
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
  interface FleetSweep {
    fleet: Address
    fleetName: string
    bufferArk: Address
    bufferBalance: bigint
    isSweepable: boolean
    isNonSweepable: boolean
    timelockHasCurator: boolean
  }
  interface CampaignPlan {
    cfg: DistributionCampaignConfig
    sweeps: FleetSweep[]
    asset: Address
    assetSymbol: string
    assetDecimals: number
    totalBufferBalance: bigint
    amount: bigint
    actions: PlannedAction[]
  }
  const plans: CampaignPlan[] = []

  const nowSec = Math.floor(Date.now() / 1000)
  for (const cfg of campaigns) {
    console.log(kleur.blue(`\nValidating campaign "${cfg.name}"…`))
    if (cfg.sweepFleets.length === 0) fail(`${cfg.name}: sweepFleets is empty.`)

    const sweeps: FleetSweep[] = []
    let asset: Address | undefined
    for (const fleetAddr of cfg.sweepFleets) {
      const fleet = getAddress(fleetAddr)
      const [fleetName, bufferArkRaw, assetRaw, paused] = await Promise.all([
        publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'name' }),
        publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'bufferArk' }),
        publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'asset' }),
        publicClient.readContract({ address: fleet, abi: fleetAbi, functionName: 'paused' }),
      ])
      const bufferArk = getAddress(bufferArkRaw as string)
      const fleetAsset = getAddress(assetRaw as string)
      if (asset === undefined) asset = fleetAsset
      if (fleetAsset !== asset) {
        fail(
          `${cfg.name}: fleet ${fleetName} asset ${fleetAsset} differs from campaign asset ${asset} — ` +
            `all sweepFleets must share the same underlying.`,
        )
      }
      if (!paused) {
        console.log(
          kleur.yellow(
            `  ⚠ ${fleetName} is NOT paused — its buffer balance can change before execution; ` +
              `a pinned amount may end up exceeding the swept total (createCampaign would revert the batch).`,
          ),
        )
      }
      const [bufferBalance, isSweepable, isNonSweepable, timelockHasCurator] = await Promise.all([
        publicClient.readContract({
          address: asset,
          abi: erc20Abi,
          functionName: 'balanceOf',
          args: [bufferArk],
        }),
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
      if (bufferBalance === 0n) {
        console.log(
          kleur.yellow(`  ⚠ ${fleetName}: buffer balance is 0 — nothing to sweep there.`),
        )
      }
      sweeps.push({
        fleet,
        fleetName,
        bufferArk,
        bufferBalance,
        isSweepable,
        isNonSweepable,
        timelockHasCurator,
      })
    }
    const campaignAsset = asset!

    const [assetSymbol, assetDecimals] = await Promise.all([
      publicClient.readContract({ address: campaignAsset, abi: erc20Abi, functionName: 'symbol' }),
      publicClient.readContract({
        address: campaignAsset,
        abi: erc20Abi,
        functionName: 'decimals',
      }),
    ])

    const totalBufferBalance = sweeps.reduce((s, x) => s + x.bufferBalance, 0n)
    const amount = cfg.amount === 'live' ? totalBufferBalance : BigInt(cfg.amount)
    if (amount === 0n) fail(`${cfg.name}: campaign amount is 0 — nothing to distribute.`)
    if (amount > totalBufferBalance) {
      fail(
        `${cfg.name}: pinned amount ${amount} exceeds the combined live buffer balance ` +
          `${totalBufferBalance} — regenerate after expected inflows land (or lower the amount).`,
      )
    }
    if (!/^0x[0-9a-fA-F]+$/.test(cfg.campaignData) || cfg.campaignData.length < 10) {
      fail(
        `${cfg.name}: campaignData looks invalid (${cfg.campaignData.slice(0, 20)}…) — paste the ` +
          `bytes generated by Merkl Studio / the Merkl API.`,
      )
    }
    if (cfg.startTimestamp <= nowSec) {
      fail(
        `${cfg.name}: startTimestamp ${cfg.startTimestamp} is in the past — the campaign must start ` +
          `after the proposal executes (vote + timelock + LayerZero ≈ days; pick a comfortable buffer).`,
      )
    }
    if (cfg.duration <= 0) fail(`${cfg.name}: duration must be > 0 seconds.`)

    // Merkl-side sanity: reward token must be whitelisted with a min hourly amount
    const minAmount = await publicClient.readContract({
      address: distributionCreator,
      abi: merklAbi,
      functionName: 'rewardTokenMinAmounts',
      args: [campaignAsset],
    })
    if (minAmount === 0n) {
      fail(`${cfg.name}: ${assetSymbol} is not whitelisted as a Merkl reward token on ${network}.`)
    }
    if (amount * 3600n < minAmount * BigInt(cfg.duration)) {
      fail(
        `${cfg.name}: amount ${amount} over ${cfg.duration}s is below Merkl's minimum ` +
          `(${minAmount}/hour for ${assetSymbol}).`,
      )
    }

    // ---- Ordered actions ----
    const actions: PlannedAction[] = []
    for (const s of sweeps.filter((x) => x.bufferBalance > 0n)) {
      const grantCurator = !s.isSweepable && !s.timelockHasCurator
      if (grantCurator) {
        actions.push({
          target: pamAddress,
          calldata: encodeFunctionData({
            abi: pamWriteAbi,
            functionName: 'grantCuratorRole',
            args: [s.fleet, timelock],
          }),
          summary: `PAM.grantCuratorRole(${s.fleetName}, timelock) — temporary, for setSweepableToken`,
        })
      }
      if (!s.isSweepable) {
        actions.push({
          target: raftAddress,
          calldata: encodeFunctionData({
            abi: raftWriteAbi,
            functionName: 'setSweepableToken',
            args: [s.bufferArk, campaignAsset, true],
          }),
          summary: `Raft.setSweepableToken(${s.fleetName} bufferArk, ${assetSymbol}, true)`,
        })
      }
      if (s.isNonSweepable) {
        actions.push({
          target: raftAddress,
          calldata: encodeFunctionData({
            abi: raftWriteAbi,
            functionName: 'setNonSweepableToken',
            args: [s.bufferArk, campaignAsset, false],
          }),
          summary: `Raft.setNonSweepableToken(${s.fleetName} bufferArk, ${assetSymbol}, false) — lift blacklist`,
        })
      }
      actions.push({
        target: raftAddress,
        calldata: encodeFunctionData({
          abi: raftWriteAbi,
          functionName: 'socializeLosses',
          args: [s.bufferArk, [campaignAsset], timelock],
        }),
        summary: `Raft.socializeLosses(${s.fleetName} bufferArk, [${assetSymbol}], timelock) — sweeps ${formatAssets(s.bufferBalance, assetDecimals, assetSymbol)}`,
      })
      if (s.isNonSweepable) {
        actions.push({
          target: raftAddress,
          calldata: encodeFunctionData({
            abi: raftWriteAbi,
            functionName: 'setNonSweepableToken',
            args: [s.bufferArk, campaignAsset, true],
          }),
          summary: `Raft.setNonSweepableToken(${s.fleetName} bufferArk, ${assetSymbol}, true) — restore blacklist`,
        })
      }
      if (!s.isSweepable) {
        actions.push({
          target: raftAddress,
          calldata: encodeFunctionData({
            abi: raftWriteAbi,
            functionName: 'setSweepableToken',
            args: [s.bufferArk, campaignAsset, false],
          }),
          summary: `Raft.setSweepableToken(${s.fleetName} bufferArk, ${assetSymbol}, false) — restore whitelist`,
        })
      }
      if (grantCurator) {
        actions.push({
          target: pamAddress,
          calldata: encodeFunctionData({
            abi: pamWriteAbi,
            functionName: 'revokeCuratorRole',
            args: [s.fleet, timelock],
          }),
          summary: `PAM.revokeCuratorRole(${s.fleetName}, timelock) — cleanup`,
        })
      }
    }
    actions.push({
      target: campaignAsset,
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
            rewardToken: campaignAsset,
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
      sweeps,
      asset: campaignAsset,
      assetSymbol,
      assetDecimals,
      totalBufferBalance,
      amount,
      actions,
    })
  }

  // ---- Summary ----
  console.log(kleur.cyan().bold('\n================ Distribution plan ================'))
  for (const p of plans) {
    console.log(kleur.yellow(`\nCampaign "${p.cfg.name}"`))
    for (const s of p.sweeps) {
      console.log(
        `  sweep ${s.fleetName.padEnd(30)}: ${formatAssets(s.bufferBalance, p.assetDecimals, p.assetSymbol)} ` +
          `(sweepable=${s.isSweepable} nonSweepable=${s.isNonSweepable})`,
      )
    }
    console.log(
      kleur.red(
        `  distribute     : ${formatAssets(p.amount, p.assetDecimals, p.assetSymbol)} via ONE Merkl campaign ` +
          `(type ${p.cfg.campaignType}; the 0.5% type-4 fee is added ON TOP of JSON allocations — ` +
          `allocations must sum to amount/1.005)`,
      ),
    )
    p.actions.forEach((a, i) => console.log(kleur.yellow(`  ${i + 1}. ${a.summary}`)))
  }
  console.log(
    kleur
      .red()
      .bold(
        `\n⚠️  Sweeping the buffers removes the assets backing the fleets' shares — share prices drop ` +
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

  // ---- Emit one proposal per campaign ----
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const prefix = useBummerConfig ? 'test' : 'prod'
  const writtenFiles: string[] = []

  for (const p of plans) {
    const sweepLines = p.sweeps
      .map(
        (s) =>
          `- ${s.fleetName} buffer ${s.bufferArk}: ${formatAssets(s.bufferBalance, p.assetDecimals, p.assetSymbol)}`,
      )
      .join('\n')
    const description =
      `# Fleet distribution — ${p.cfg.name}\n\n` +
      (fleetIsHub
        ? `Executed on the ${HUB_CHAIN_NAME} hub by the timelock ${timelock}.`
        : `Created on the ${HUB_CHAIN_NAME} hub and relayed via LayerZero to the ${network} timelock ${timelock} for execution.`) +
      `\n\nSweeps the buffer arks of ${p.sweeps.length} fleet(s) into the timelock:\n${sweepLines}\n\n` +
      `and creates ONE Merkl campaign (type ${p.cfg.campaignType}) distributing ` +
      `${formatAssets(p.amount, p.assetDecimals, p.assetSymbol)} to users per the off-chain allocation ` +
      `JSON (per-fleet entitlements are encoded in the airdrop reasons). The fleets remain paused ` +
      `throughout.\n\n## Actions\n` +
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
      `${prefix}_fleet_distribution_proposal_${sanitizeFleetName(p.cfg.name)}_${network}_${timestamp}.json`,
    )
    await createGovernanceProposal(
      `Fleet distribution — ${p.cfg.name} (${network})`,
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
        'campaignData (allocations summing to amount/1.005), and the campaign startTimestamp must ' +
        'still be in the future when the proposal executes on the satellite.',
    ),
  )
}

main().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
