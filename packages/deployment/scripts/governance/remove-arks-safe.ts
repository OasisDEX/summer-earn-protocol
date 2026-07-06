import fs from 'node:fs'
import path from 'node:path'

import hre from 'hardhat'
import kleur from 'kleur'
import prompts from 'prompts'
import { Address, encodeFunctionData, formatUnits, getAddress, parseAbi } from 'viem'

import { BaseConfig } from '../../types/config-types'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getChainId } from '../helpers/get-chainid'
import { promptForConfigType } from '../helpers/prompt-helpers'

/**
 * Crafts Safe transaction batches (Safe Transaction Builder JSON) for the governor Safe to
 * remove Arks from their FleetCommanders.
 *
 * For arks that still report assets (`totalAssets() > 0`) the stuck receipt/share tokens
 * (the `pool` address from the ark's `details()` JSON) are recovered first via
 * `Raft.socializeLosses(ark, [pool], receiver)`, which requires temporarily whitelisting the
 * token as sweepable (curator role — self-granted by the governor Safe) and lifting the
 * governance non-sweepable blacklist. All flags/roles are restored in the same batch.
 *
 * Output is split in two phases because `removeArk` is `whenNotPaused` while the sweep path
 * is not, and a paused fleet cannot be unpaused before `pauseStartTime + minimumPauseTime`:
 * - phase 1 (sweep) is executable immediately
 * - phase 2 (unpause + removeArk [+ re-pause]) only after the pause window elapses
 *
 * Non-interactive usage (all optional, prompts otherwise):
 *   BUMMER=true|false SAFE_ADDRESS=0x.. RECEIVER=0x.. ARKS=0x..,0x.. YES=1 REPAUSE=true|false \
 *     NETWORK=mainnet pnpm gov:remove-arks
 */

const arkAbi = parseAbi([
  'function commander() view returns (address)',
  'function totalAssets() view returns (uint256)',
  'function depositCap() view returns (uint256)',
  'function details() view returns (string)',
  'function asset() view returns (address)',
])

const fleetAbi = parseAbi([
  'function name() view returns (string)',
  'function getActiveArks() view returns (address[])',
  'function bufferArk() view returns (address)',
  'function paused() view returns (bool)',
  'function pauseStartTime() view returns (uint256)',
  'function minimumPauseTime() view returns (uint256)',
])

const raftViewAbi = parseAbi([
  'function sweepableTokens(address ark, address token) view returns (bool)',
  'function nonSweepableTokens(address ark, address token) view returns (bool)',
])

const pamViewAbi = parseAbi([
  'function GOVERNOR_ROLE() view returns (bytes32)',
  'function generateRole(uint8 roleName, address roleTargetContract) pure returns (bytes32)',
  'function hasRole(bytes32 role, address account) view returns (bool)',
])

const erc20Abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
])

// Write ABIs as JSON fragments so the Safe Transaction Builder `contractMethod` metadata can be
// derived from the same source used for calldata encoding.
const writeAbis = {
  grantCuratorRole: {
    name: 'grantCuratorRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'fleetCommanderAddress', type: 'address' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  revokeCuratorRole: {
    name: 'revokeCuratorRole',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'fleetCommanderAddress', type: 'address' },
      { name: 'account', type: 'address' },
    ],
    outputs: [],
  },
  setSweepableToken: {
    name: 'setSweepableToken',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'isSweepable', type: 'bool' },
    ],
    outputs: [],
  },
  setNonSweepableToken: {
    name: 'setNonSweepableToken',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'isNonSweepable', type: 'bool' },
    ],
    outputs: [],
  },
  socializeLosses: {
    name: 'socializeLosses',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'tokens', type: 'address[]' },
      { name: 'receiver', type: 'address' },
    ],
    outputs: [],
  },
  setArkDepositCap: {
    name: 'setArkDepositCap',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'ark', type: 'address' },
      { name: 'newDepositCap', type: 'uint256' },
    ],
    outputs: [],
  },
  removeArk: {
    name: 'removeArk',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'ark', type: 'address' }],
    outputs: [],
  },
  unpause: {
    name: 'unpause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  pause: {
    name: 'pause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
} as const

const CURATOR_ROLE_ENUM = 0 // ContractSpecificRoles.CURATOR_ROLE

interface SafeTx {
  to: string
  value: string
  data: string
  contractMethod: {
    inputs: readonly { name: string; type: string }[]
    name: string
    payable: boolean
  }
  contractInputsValues: Record<string, string>
}

interface BatchAction {
  tx: SafeTx
  summary: string
}

interface ArkPlan {
  ark: Address
  fleet: Address
  fleetName: string
  totalAssets: bigint
  depositCap: bigint
  assetSymbol: string
  assetDecimals: number
  needsSweep: boolean
  pool?: Address
  poolSymbol?: string
  poolBalance?: bigint
  isSweepable?: boolean
  isNonSweepable?: boolean
  fleetPaused: boolean
  unpauseNotBefore?: Date
  safeHasCurator: boolean
}

function buildTx(
  to: Address,
  abiFragment: (typeof writeAbis)[keyof typeof writeAbis],
  args: readonly unknown[],
): SafeTx {
  const data = encodeFunctionData({
    abi: [abiFragment],
    functionName: abiFragment.name,
    args: args as never,
  })
  const contractInputsValues: Record<string, string> = {}
  abiFragment.inputs.forEach((input, i) => {
    const value = args[i]
    contractInputsValues[input.name] = Array.isArray(value) ? JSON.stringify(value) : String(value)
  })
  return {
    to: getAddress(to),
    value: '0',
    data,
    contractMethod: {
      inputs: abiFragment.inputs,
      name: abiFragment.name,
      payable: false,
    },
    contractInputsValues,
  }
}

function writeSafeBatch(
  actions: BatchAction[],
  meta: { name: string; description: string; safeAddress: Address; chainId: number },
  outFile: string,
): string {
  const batch = {
    version: '1.0',
    chainId: meta.chainId.toString(),
    createdAt: Date.now(),
    meta: {
      name: meta.name,
      description: meta.description,
      txBuilderVersion: '1.16.5',
      createdFromSafeAddress: meta.safeAddress,
      createdFromOwnerAddress: '',
      checksum: '',
    },
    transactions: actions.map((a) => a.tx),
  }
  fs.mkdirSync(path.dirname(outFile), { recursive: true })
  fs.writeFileSync(outFile, JSON.stringify(batch, null, 2))
  return outFile
}

function printActions(label: string, actions: BatchAction[]) {
  console.log(kleur.cyan().bold(`\n${label} (${actions.length} actions):`))
  actions.forEach((a, i) => {
    console.log(kleur.yellow(`  ${i + 1}. ${a.summary}`))
    console.log(kleur.gray(`     to: ${a.tx.to}  data: ${a.tx.data.slice(0, 10)}…`))
  })
}

function parseAddressList(value: string): Address[] {
  const list = value
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
  return [...new Set(list.map((a) => getAddress(a)))]
}

async function promptForArkAddresses(): Promise<Address[]> {
  const { arkInput } = await prompts({
    type: 'text',
    name: 'arkInput',
    message: 'Enter the ark address(es) to remove (comma-separated):',
    validate: (val: string) => {
      const arr = val
        .split(',')
        .map((s) => s.trim())
        .filter((s) => s.length > 0)
      if (arr.length === 0) return 'At least one ark address is required'
      for (const a of arr) {
        if (!/^0x[a-fA-F0-9]{40}$/.test(a)) return `Invalid address: ${a}`
      }
      return true
    },
  })
  if (!arkInput) {
    throw new Error('Ark address input is required')
  }
  return parseAddressList(arkInput)
}

async function promptForAddressWithDefault(message: string, initial: Address): Promise<Address> {
  const { value } = await prompts({
    type: 'text',
    name: 'value',
    message,
    initial,
    validate: (val: string) => (/^0x[a-fA-F0-9]{40}$/.test(val.trim()) ? true : 'Invalid address'),
  })
  if (!value) {
    throw new Error('Address input is required')
  }
  return getAddress(value.trim())
}

async function main() {
  const network = hre.network.name
  const chainId = getChainId()
  console.log(kleur.blue('Network:'), kleur.cyan(`${network} (chainId ${chainId})`))

  const useBummerConfig =
    process.env.BUMMER !== undefined ? process.env.BUMMER === 'true' : await promptForConfigType()

  const config = getConfigByNetwork(
    network,
    { common: true, core: true, gov: true },
    useBummerConfig,
  ) as BaseConfig

  const raftAddress = getAddress(config.deployedContracts.core.raft.address)
  const pamAddress = getAddress(config.deployedContracts.gov.protocolAccessManager.address)
  const foundationAddress = getAddress(config.common.foundation)

  const publicClient = await hre.viem.getPublicClient()

  const safeAddress = process.env.SAFE_ADDRESS
    ? getAddress(process.env.SAFE_ADDRESS)
    : await promptForAddressWithDefault(
        'Governor Safe address (executes the batches):',
        foundationAddress,
      )

  const receiverAddress = process.env.RECEIVER
    ? getAddress(process.env.RECEIVER)
    : await promptForAddressWithDefault('Receiver of the swept tokens:', safeAddress)

  const arks = process.env.ARKS ? parseAddressList(process.env.ARKS) : await promptForArkAddresses()

  // The whole plan hinges on the Safe holding GOVERNOR_ROLE — verify before building anything
  const governorRole = await publicClient.readContract({
    address: pamAddress,
    abi: pamViewAbi,
    functionName: 'GOVERNOR_ROLE',
  })
  const safeIsGovernor = await publicClient.readContract({
    address: pamAddress,
    abi: pamViewAbi,
    functionName: 'hasRole',
    args: [governorRole, safeAddress],
  })
  if (!safeIsGovernor) {
    console.log(
      kleur.red(
        `❌ ${safeAddress} does not hold GOVERNOR_ROLE on ProtocolAccessManager ${pamAddress} — aborting.`,
      ),
    )
    process.exit(1)
  }
  console.log(kleur.green(`✓ ${safeAddress} holds GOVERNOR_ROLE`))

  // Inspect every ark on-chain and build a removal plan
  const plans: ArkPlan[] = []
  const fleetCache = new Map<
    Address,
    {
      fleetName: string
      activeArks: Address[]
      bufferArk: Address
      paused: boolean
      unpauseNotBefore?: Date
      safeHasCurator: boolean
    }
  >()

  for (const ark of arks) {
    console.log(kleur.blue(`\nInspecting ark ${ark}…`))

    const [fleet, totalAssets, depositCap, detailsJson, assetAddress] = await Promise.all([
      publicClient.readContract({ address: ark, abi: arkAbi, functionName: 'commander' }),
      publicClient.readContract({ address: ark, abi: arkAbi, functionName: 'totalAssets' }),
      publicClient.readContract({ address: ark, abi: arkAbi, functionName: 'depositCap' }),
      publicClient.readContract({ address: ark, abi: arkAbi, functionName: 'details' }),
      publicClient.readContract({ address: ark, abi: arkAbi, functionName: 'asset' }),
    ])
    const fleetAddress = getAddress(fleet)

    if (fleetAddress === getAddress('0x0000000000000000000000000000000000000000')) {
      console.log(kleur.red(`❌ Ark ${ark} has no commander (already removed?) — aborting.`))
      process.exit(1)
    }

    let fleetInfo = fleetCache.get(fleetAddress)
    if (!fleetInfo) {
      const [fleetName, activeArks, bufferArk, paused, pauseStartTime, minimumPauseTime] =
        await Promise.all([
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
          publicClient.readContract({
            address: fleetAddress,
            abi: fleetAbi,
            functionName: 'paused',
          }),
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
        ])
      const curatorRole = await publicClient.readContract({
        address: pamAddress,
        abi: pamViewAbi,
        functionName: 'generateRole',
        args: [CURATOR_ROLE_ENUM, fleetAddress],
      })
      const safeHasCurator = await publicClient.readContract({
        address: pamAddress,
        abi: pamViewAbi,
        functionName: 'hasRole',
        args: [curatorRole, safeAddress],
      })
      fleetInfo = {
        fleetName,
        activeArks: activeArks.map((a) => getAddress(a)),
        bufferArk: getAddress(bufferArk),
        paused,
        unpauseNotBefore: paused
          ? new Date(Number(pauseStartTime + minimumPauseTime) * 1000)
          : undefined,
        safeHasCurator,
      }
      fleetCache.set(fleetAddress, fleetInfo)
    }

    if (getAddress(ark) === fleetInfo.bufferArk) {
      console.log(kleur.red(`❌ Ark ${ark} is the buffer ark of ${fleetAddress} — aborting.`))
      process.exit(1)
    }
    if (!fleetInfo.activeArks.includes(getAddress(ark))) {
      console.log(
        kleur.red(`❌ Ark ${ark} is not an active ark of fleet ${fleetAddress} — aborting.`),
      )
      process.exit(1)
    }

    const [assetSymbol, assetDecimals] = await Promise.all([
      publicClient.readContract({ address: assetAddress, abi: erc20Abi, functionName: 'symbol' }),
      publicClient.readContract({ address: assetAddress, abi: erc20Abi, functionName: 'decimals' }),
    ])

    const plan: ArkPlan = {
      ark: getAddress(ark),
      fleet: fleetAddress,
      fleetName: fleetInfo.fleetName,
      totalAssets,
      depositCap,
      assetSymbol,
      assetDecimals,
      needsSweep: totalAssets > 0n,
      fleetPaused: fleetInfo.paused,
      unpauseNotBefore: fleetInfo.unpauseNotBefore,
      safeHasCurator: fleetInfo.safeHasCurator,
    }

    if (plan.needsSweep) {
      // totalAssets is backed by receipt/share tokens; the `pool` key of the details JSON is the
      // share token for vault-style arks. Verify that assumption holds before planning a sweep.
      let details: Record<string, unknown>
      try {
        details = JSON.parse(detailsJson)
      } catch {
        console.log(
          kleur.red(`❌ Ark ${ark} details() is not valid JSON (${detailsJson}) — aborting.`),
        )
        process.exit(1)
      }
      if (typeof details.pool !== 'string' || !/^0x[a-fA-F0-9]{40}$/.test(details.pool)) {
        console.log(
          kleur.red(
            `❌ Ark ${ark} has assets but details() has no usable "pool" address (${detailsJson}) — handle manually, aborting.`,
          ),
        )
        process.exit(1)
      }
      const pool = getAddress(details.pool)
      const poolBalance = await publicClient.readContract({
        address: pool,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [plan.ark],
      })
      if (poolBalance === 0n) {
        console.log(
          kleur.red(
            `❌ Ark ${ark} reports totalAssets ${totalAssets} but holds no balance of details().pool token ${pool}.` +
              ` Sweeping that token would not zero totalAssets — handle manually, aborting.`,
          ),
        )
        process.exit(1)
      }
      let poolSymbol = '???'
      try {
        poolSymbol = await publicClient.readContract({
          address: pool,
          abi: erc20Abi,
          functionName: 'symbol',
        })
      } catch {
        // non-standard token symbol — cosmetic only
      }
      const [isSweepable, isNonSweepable] = await Promise.all([
        publicClient.readContract({
          address: raftAddress,
          abi: raftViewAbi,
          functionName: 'sweepableTokens',
          args: [plan.ark, pool],
        }),
        publicClient.readContract({
          address: raftAddress,
          abi: raftViewAbi,
          functionName: 'nonSweepableTokens',
          args: [plan.ark, pool],
        }),
      ])
      plan.pool = pool
      plan.poolSymbol = poolSymbol
      plan.poolBalance = poolBalance
      plan.isSweepable = isSweepable
      plan.isNonSweepable = isNonSweepable
    }

    plans.push(plan)
  }

  // Summary — this batch moves user-fund backing out of fleets, so make the numbers loud
  console.log(kleur.cyan().bold('\n================ Removal plan ================'))
  for (const p of plans) {
    console.log(kleur.yellow(`\nArk ${p.ark}`))
    console.log(`  Fleet          : ${p.fleet} (${p.fleetName})`)
    console.log(
      `  totalAssets    : ${formatUnits(p.totalAssets, p.assetDecimals)} ${p.assetSymbol}`,
    )
    console.log(`  depositCap     : ${p.depositCap}`)
    if (p.needsSweep) {
      console.log(
        kleur.red(
          `  sweep          : ${p.poolBalance} ${p.poolSymbol} (${p.pool}) → ${receiverAddress}`,
        ),
      )
      console.log(`  raft flags     : sweepable=${p.isSweepable} nonSweepable=${p.isNonSweepable}`)
    } else {
      console.log(kleur.green('  sweep          : not needed (totalAssets == 0)'))
    }
    if (p.fleetPaused) {
      console.log(
        kleur.red(
          `  fleet paused   : yes — unpause/removeArk executable after ${p.unpauseNotBefore?.toISOString()}`,
        ),
      )
    }
  }
  const totalSwept = plans.filter((p) => p.needsSweep)
  if (totalSwept.length > 0) {
    console.log(
      kleur
        .red()
        .bold(
          `\n⚠️  Sweeping removes the assets backing ${totalSwept.length} ark(s) from fleet accounting` +
            ` (fleet share price will drop accordingly — this socializes the losses).`,
        ),
    )
  }

  if (process.env.YES !== '1') {
    const { confirmed } = await prompts({
      type: 'confirm',
      name: 'confirmed',
      message: 'Build the Safe transaction batches for this plan?',
      initial: false,
    })
    if (!confirmed) {
      console.log(kleur.red('Operation cancelled by user.'))
      return
    }
  }

  const pausedFleets = [...fleetCache.entries()].filter(([, f]) => f.paused)
  let includeRepause = false
  if (pausedFleets.length > 0) {
    includeRepause =
      process.env.REPAUSE !== undefined
        ? process.env.REPAUSE === 'true'
        : (
            await prompts({
              type: 'confirm',
              name: 'confirmed',
              message:
                'Re-pause the paused fleet(s) after removeArk? (note: restarts the 2-day minimum pause window)',
              initial: false,
            })
          ).confirmed === true
  }

  // ---------------- Phase 1: sweep stuck assets via socializeLosses ----------------
  const phase1: BatchAction[] = []
  const fleetsNeedingPhase1CuratorGrant = new Set(
    plans.filter((p) => p.needsSweep && !p.isSweepable && !p.safeHasCurator).map((p) => p.fleet),
  )

  for (const fleet of fleetsNeedingPhase1CuratorGrant) {
    phase1.push({
      tx: buildTx(pamAddress, writeAbis.grantCuratorRole, [fleet, safeAddress]),
      summary: `PAM.grantCuratorRole(${fleet}, safe) — temporary, needed for setSweepableToken`,
    })
  }
  for (const p of plans.filter((pl) => pl.needsSweep)) {
    if (!p.isSweepable) {
      phase1.push({
        tx: buildTx(raftAddress, writeAbis.setSweepableToken, [p.ark, p.pool!, true]),
        summary: `Raft.setSweepableToken(${p.ark}, ${p.poolSymbol}, true)`,
      })
    }
    if (p.isNonSweepable) {
      phase1.push({
        tx: buildTx(raftAddress, writeAbis.setNonSweepableToken, [p.ark, p.pool!, false]),
        summary: `Raft.setNonSweepableToken(${p.ark}, ${p.poolSymbol}, false) — lift blacklist`,
      })
    }
    phase1.push({
      tx: buildTx(raftAddress, writeAbis.socializeLosses, [p.ark, [p.pool!], receiverAddress]),
      summary: `Raft.socializeLosses(${p.ark}, [${p.poolSymbol}], ${receiverAddress}) — sweeps ${p.poolBalance} shares`,
    })
    // restore the exact prior flag state
    if (p.isNonSweepable) {
      phase1.push({
        tx: buildTx(raftAddress, writeAbis.setNonSweepableToken, [p.ark, p.pool!, true]),
        summary: `Raft.setNonSweepableToken(${p.ark}, ${p.poolSymbol}, true) — restore blacklist`,
      })
    }
    if (!p.isSweepable) {
      phase1.push({
        tx: buildTx(raftAddress, writeAbis.setSweepableToken, [p.ark, p.pool!, false]),
        summary: `Raft.setSweepableToken(${p.ark}, ${p.poolSymbol}, false) — restore whitelist`,
      })
    }
  }
  for (const fleet of fleetsNeedingPhase1CuratorGrant) {
    phase1.push({
      tx: buildTx(pamAddress, writeAbis.revokeCuratorRole, [fleet, safeAddress]),
      summary: `PAM.revokeCuratorRole(${fleet}, safe) — cleanup`,
    })
  }

  // ---------------- Phase 2: unpause (if needed) + removeArk [+ re-pause] ----------------
  const phase2: BatchAction[] = []
  const fleets = [...new Set(plans.map((p) => p.fleet))]
  for (const fleet of fleets) {
    const fleetPlans = plans.filter((p) => p.fleet === fleet)
    const fleetInfo = fleetCache.get(fleet)!
    const capPlans = fleetPlans.filter((p) => p.depositCap > 0n)

    if (fleetInfo.paused) {
      phase2.push({
        tx: buildTx(fleet, writeAbis.unpause, []),
        summary: `FleetCommander(${fleetInfo.fleetName}).unpause() — not before ${fleetInfo.unpauseNotBefore?.toISOString()}`,
      })
    }
    // setArkDepositCap is curator-gated and whenNotPaused, so it lives here in phase 2
    if (capPlans.length > 0 && !fleetInfo.safeHasCurator) {
      phase2.push({
        tx: buildTx(pamAddress, writeAbis.grantCuratorRole, [fleet, safeAddress]),
        summary: `PAM.grantCuratorRole(${fleet}, safe) — temporary, needed for setArkDepositCap`,
      })
    }
    for (const p of capPlans) {
      phase2.push({
        tx: buildTx(fleet, writeAbis.setArkDepositCap, [p.ark, 0n]),
        summary: `FleetCommander.setArkDepositCap(${p.ark}, 0)`,
      })
    }
    for (const p of fleetPlans) {
      phase2.push({
        tx: buildTx(fleet, writeAbis.removeArk, [p.ark]),
        summary: `FleetCommander(${fleetInfo.fleetName}).removeArk(${p.ark})`,
      })
    }
    if (capPlans.length > 0 && !fleetInfo.safeHasCurator) {
      phase2.push({
        tx: buildTx(pamAddress, writeAbis.revokeCuratorRole, [fleet, safeAddress]),
        summary: `PAM.revokeCuratorRole(${fleet}, safe) — cleanup`,
      })
    }
    if (fleetInfo.paused && includeRepause) {
      phase2.push({
        tx: buildTx(fleet, writeAbis.pause, []),
        summary: `FleetCommander(${fleetInfo.fleetName}).pause() — restore paused state`,
      })
    }
  }

  printActions('Phase 1 — sweep stuck assets (executable immediately)', phase1)
  printActions('Phase 2 — remove arks', phase2)

  const unpauseDeadlines = [...fleetCache.values()]
    .filter((f) => f.paused && f.unpauseNotBefore)
    .map((f) => f.unpauseNotBefore!)
  const earliestPhase2 =
    unpauseDeadlines.length > 0
      ? new Date(Math.max(...unpauseDeadlines.map((d) => d.getTime())))
      : undefined

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const prefix = useBummerConfig ? 'test' : 'prod'
  const proposalsDir = path.join(__dirname, '..', '..', 'proposals')

  const writtenFiles: string[] = []
  if (phase1.length > 0) {
    writtenFiles.push(
      writeSafeBatch(
        phase1,
        {
          name: 'Remove arks — phase 1: sweep stuck assets',
          description:
            `Recovers stuck receipt tokens from ark(s) ${plans
              .filter((p) => p.needsSweep)
              .map((p) => p.ark)
              .join(', ')} to ${receiverAddress} via Raft.socializeLosses, temporarily flipping ` +
            'the sweepable whitelist/blacklist and restoring it afterwards.',
          safeAddress,
          chainId,
        },
        path.join(proposalsDir, `${prefix}_remove_arks_phase1_sweep_${network}_${timestamp}.json`),
      ),
    )
  } else {
    console.log(kleur.gray('\nPhase 1 is empty (no ark needs sweeping) — no file written.'))
  }
  writtenFiles.push(
    writeSafeBatch(
      phase2,
      {
        name: 'Remove arks — phase 2: removeArk',
        description:
          `Removes ark(s) ${plans.map((p) => p.ark).join(', ')} from their FleetCommander(s).` +
          (earliestPhase2 ? ` NOT EXECUTABLE BEFORE ${earliestPhase2.toISOString()}.` : ''),
        safeAddress,
        chainId,
      },
      path.join(proposalsDir, `${prefix}_remove_arks_phase2_remove_${network}_${timestamp}.json`),
    ),
  )

  console.log(kleur.green().bold('\n✅ Safe transaction batches written:'))
  for (const f of writtenFiles) {
    console.log(kleur.green(`   ${f}`))
  }
  console.log(
    kleur.cyan(
      '\nImport each file in the Safe web UI: Apps → Transaction Builder → drag & drop the JSON, then review the decoded actions and collect signatures.',
    ),
  )
  if (earliestPhase2) {
    console.log(
      kleur
        .red()
        .bold(
          `⚠️  Phase 2 will revert if executed before ${earliestPhase2.toISOString()} (minimum pause time).`,
        ),
    )
  }
  console.log(
    kleur.gray(
      'After execution, remember to update the fleet deployment JSON (deployments/fleets/) and curation arks.json by hand.',
    ),
  )
}

main().catch((error) => {
  console.error(kleur.red().bold('An error occurred:'), error)
  process.exit(1)
})
