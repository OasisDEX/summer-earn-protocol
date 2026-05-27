import kleur from 'kleur'
import prompts from 'prompts'
import { Address, decodeAbiParameters, encodeAbiParameters } from 'viem'
import { BaseConfig, SupportedNetworks } from '../../types/config-types'
import { ADDRESS_ZERO } from '../common/constants'
import { getChainPublicClient } from '../helpers/client-by-chain-helper'
import { getConfigByNetwork } from '../helpers/config-handler'
import { getHubChain } from '../helpers/get-hub-chain'
import { LZ_ENDPOINT_ABI } from './bridge/lz-endpoint-abi'
import { createUnifiedLzConfigProposal } from './bridge/helpers/bridge-governance-helper'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface UlnConfig {
  confirmations: bigint
  requiredDVNCount: number
  optionalDVNCount: number
  optionalDVNThreshold: number
  requiredDVNs: readonly Address[]
  optionalDVNs: readonly Address[]
}

interface ConfigDiff {
  chain: string
  remoteChain: string
  remoteEid: number
  oAppName: string
  oAppAddress: Address
  lzEndpointAddress: Address
  sendLibAddress: Address
  receiveLibAddress: Address
  encodedExecutor: `0x${string}`
  encodedUln: `0x${string}`
  sendNeedsUpdate: boolean
  receiveNeedsUpdate: boolean
}

// ---------------------------------------------------------------------------
// ABI encode/decode helpers
// ---------------------------------------------------------------------------

const ULN_CONFIG_DECODE_PARAMS = [
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

const ULN_CONFIG_ENCODE_PARAMS = [
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

const EXECUTOR_CONFIG_ENCODE_PARAMS = [
  {
    type: 'tuple',
    components: [
      { name: 'maxMessageSize', type: 'uint32' },
      { name: 'executorAddress', type: 'address' },
    ],
  },
] as const

// ---------------------------------------------------------------------------
// ULN comparison
// ---------------------------------------------------------------------------

function ulnConfigsMatch(a: UlnConfig | null, b: UlnConfig): boolean {
  if (a === null) return false

  if (a.confirmations !== b.confirmations) return false
  if (a.requiredDVNCount !== b.requiredDVNCount) return false
  if (a.optionalDVNCount !== b.optionalDVNCount) return false
  if (a.optionalDVNThreshold !== b.optionalDVNThreshold) return false

  const sortAddrs = (arr: readonly Address[]) =>
    [...arr].sort((x, y) => x.toLowerCase().localeCompare(y.toLowerCase()))

  const aReq = sortAddrs(a.requiredDVNs)
  const bReq = sortAddrs(b.requiredDVNs)
  if (aReq.length !== bReq.length) return false
  for (let i = 0; i < aReq.length; i++) {
    if (aReq[i].toLowerCase() !== bReq[i].toLowerCase()) return false
  }

  const aOpt = sortAddrs(a.optionalDVNs)
  const bOpt = sortAddrs(b.optionalDVNs)
  if (aOpt.length !== bOpt.length) return false
  for (let i = 0; i < aOpt.length; i++) {
    if (aOpt[i].toLowerCase() !== bOpt[i].toLowerCase()) return false
  }

  return true
}

// ---------------------------------------------------------------------------
// Read on-chain ULN config
// ---------------------------------------------------------------------------

async function readOnChainUlnConfig(
  publicClient: Awaited<ReturnType<typeof getChainPublicClient>>,
  endpoint: Address,
  oApp: Address,
  lib: Address,
  remoteEid: number,
): Promise<UlnConfig | null> {
  try {
    const raw = await publicClient.readContract({
      address: endpoint,
      abi: LZ_ENDPOINT_ABI,
      functionName: 'getConfig',
      args: [oApp, lib, remoteEid, 2],
    })

    // Empty bytes means default / not configured
    if (!raw || raw === '0x' || raw.length <= 2) return null

    const [decoded] = decodeAbiParameters(ULN_CONFIG_DECODE_PARAMS, raw)
    return {
      confirmations: decoded.confirmations,
      requiredDVNCount: decoded.requiredDVNCount,
      optionalDVNCount: decoded.optionalDVNCount,
      optionalDVNThreshold: decoded.optionalDVNThreshold,
      requiredDVNs: decoded.requiredDVNs as readonly Address[],
      optionalDVNs: decoded.optionalDVNs as readonly Address[],
    }
  } catch {
    return null
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function updateDvnConfig(useBummerConfig = false) {
  console.log(
    kleur
      .yellow()
      .bold(
        '\n⚠  LZ MIGRATION GUIDE WARNING ⚠\n' +
          'Send-side updates MUST be applied first (Phase 1).\n' +
          'Only after all in-flight messages have drained should you apply\n' +
          'receive-side updates (Phase 2). Running Phase 2 before drain may\n' +
          'cause in-flight messages to be rejected.\n',
      ),
  )

  const hubChain = getHubChain()
  const chains = Object.values(SupportedNetworks)

  const diffs: ConfigDiff[] = []

  for (const chain of chains) {
    // -----------------------------------------------------------------------
    // Load chain config
    // -----------------------------------------------------------------------
    let chainConfig: BaseConfig
    try {
      chainConfig = getConfigByNetwork(chain, { common: true, gov: true }, useBummerConfig) as BaseConfig
    } catch {
      console.log(kleur.yellow(`[${chain}] Skipping — no config`))
      continue
    }

    const lzEndpoint = chainConfig.common.layerZero.lzEndpoint
    if (!lzEndpoint || lzEndpoint === ADDRESS_ZERO) {
      console.log(kleur.yellow(`[${chain}] Skipping — no LZ endpoint`))
      continue
    }

    // -----------------------------------------------------------------------
    // Public client
    // -----------------------------------------------------------------------
    let publicClient: Awaited<ReturnType<typeof getChainPublicClient>>
    try {
      publicClient = await getChainPublicClient(chain)
    } catch (err: any) {
      console.log(kleur.yellow(`[${chain}] Skipping — cannot get public client: ${err.message}`))
      continue
    }

    const sendUln302 = chainConfig.common.layerZero.sendUln302 as Address
    const receiveUln302 = chainConfig.common.layerZero.receiveUln302 as Address
    const lzExecutor = chainConfig.common.layerZero.lzExecutor as Address
    const dvnsConfig = chainConfig.common.layerZero.dvns

    // -----------------------------------------------------------------------
    // OApps to check
    // -----------------------------------------------------------------------
    const oApps: { name: string; address: string | undefined }[] = [
      {
        name: 'SummerToken',
        address: chainConfig.deployedContracts?.gov?.summerToken?.address,
      },
      {
        name: 'SummerGovernorV2',
        address: chainConfig.deployedContracts?.govV2?.summerGovernor?.address,
      },
    ]

    for (const oApp of oApps) {
      if (!oApp.address || oApp.address === ADDRESS_ZERO) {
        console.log(kleur.yellow(`[${chain}] Skipping ${oApp.name} — no address`))
        continue
      }

      const oAppAddress = oApp.address as Address

      // -----------------------------------------------------------------------
      // For each remote chain configured in dvns
      // -----------------------------------------------------------------------
      for (const remoteChain of Object.keys(dvnsConfig)) {
        const dvns = dvnsConfig[remoteChain]
        if (!dvns) continue

        // Get remoteEid from remote chain's config
        let remoteChainConfig: BaseConfig
        try {
          remoteChainConfig = getConfigByNetwork(remoteChain, { common: true }, useBummerConfig) as BaseConfig
        } catch {
          console.log(kleur.yellow(`[${chain}->${remoteChain}] Skipping — no remote config`))
          continue
        }

        const remoteEidStr = remoteChainConfig.common.layerZero.eID
        if (!remoteEidStr) {
          console.log(kleur.yellow(`[${chain}->${remoteChain}] Skipping — no remote eID`))
          continue
        }
        const remoteEid = Number(remoteEidStr)

        // -----------------------------------------------------------------------
        // Build desired ULN config
        // -----------------------------------------------------------------------
        const hasThirdDvn = !!(dvns.thirdDvn && dvns.thirdDvn.length > 0)

        const desiredUln: UlnConfig = hasThirdDvn
          ? {
              confirmations: 15n,
              requiredDVNCount: 1,
              optionalDVNCount: 2,
              optionalDVNThreshold: 1,
              requiredDVNs: ([dvns.lzLabs as Address] as Address[]).sort() as readonly Address[],
              optionalDVNs: (
                [dvns.secondDvn as Address, dvns.thirdDvn as Address] as Address[]
              ).sort() as readonly Address[],
            }
          : {
              confirmations: 15n,
              requiredDVNCount: 2,
              optionalDVNCount: 0,
              optionalDVNThreshold: 0,
              requiredDVNs: (
                [dvns.lzLabs as Address, dvns.secondDvn as Address] as Address[]
              ).sort() as readonly Address[],
              optionalDVNs: [] as readonly Address[],
            }

        // Encode desired ULN
        const encodedUln = encodeAbiParameters(ULN_CONFIG_ENCODE_PARAMS, [desiredUln])

        // Encode executor config
        const encodedExecutor = encodeAbiParameters(EXECUTOR_CONFIG_ENCODE_PARAMS, [
          { maxMessageSize: 10000, executorAddress: lzExecutor },
        ])

        // -----------------------------------------------------------------------
        // Read current on-chain configs
        // -----------------------------------------------------------------------
        const currentSend = await readOnChainUlnConfig(
          publicClient,
          lzEndpoint as Address,
          oAppAddress,
          sendUln302,
          remoteEid,
        )
        const currentReceive = await readOnChainUlnConfig(
          publicClient,
          lzEndpoint as Address,
          oAppAddress,
          receiveUln302,
          remoteEid,
        )

        const sendNeedsUpdate = !ulnConfigsMatch(currentSend, desiredUln)
        const receiveNeedsUpdate = !ulnConfigsMatch(currentReceive, desiredUln)

        if (sendNeedsUpdate || receiveNeedsUpdate) {
          console.log(
            kleur.cyan(
              `[${chain}->${remoteChain}] ${oApp.name}: send=${sendNeedsUpdate ? 'NEEDS UPDATE' : 'ok'} receive=${receiveNeedsUpdate ? 'NEEDS UPDATE' : 'ok'}`,
            ),
          )
          diffs.push({
            chain,
            remoteChain,
            remoteEid,
            oAppName: oApp.name,
            oAppAddress,
            lzEndpointAddress: lzEndpoint as Address,
            sendLibAddress: sendUln302,
            receiveLibAddress: receiveUln302,
            encodedExecutor,
            encodedUln,
            sendNeedsUpdate,
            receiveNeedsUpdate,
          })
        } else {
          console.log(
            kleur.green(`[${chain}->${remoteChain}] ${oApp.name}: up to date`),
          )
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Summary
  // -------------------------------------------------------------------------
  if (diffs.length === 0) {
    console.log(kleur.green().bold('\nAll DVN configs are up to date — no proposal needed.'))
    return
  }

  console.log(
    kleur.yellow().bold(
      `\nFound ${diffs.length} config(s) that need updating across ${
        new Set(diffs.map((d) => d.chain)).size
      } chain(s).`,
    ),
  )

  // -------------------------------------------------------------------------
  // Phase selection prompt
  // -------------------------------------------------------------------------
  const { phase } = await prompts({
    type: 'select',
    name: 'phase',
    message: 'Which phase?',
    choices: [
      {
        title: 'Phase 1: Send-side updates (MUST run first)',
        value: 'send',
      },
      {
        title: 'Phase 2: Receive-side updates (run after in-flight drain)',
        value: 'receive',
      },
    ],
  })

  if (!phase) {
    console.log(kleur.yellow('No phase selected — aborting.'))
    return
  }

  // -------------------------------------------------------------------------
  // Filter diffs to the chosen phase
  // -------------------------------------------------------------------------
  const phaseDiffs = diffs.filter((d) =>
    phase === 'send' ? d.sendNeedsUpdate : d.receiveNeedsUpdate,
  )

  if (phaseDiffs.length === 0) {
    console.log(kleur.green().bold(`\nNo ${phase}-side updates needed — nothing to do.`))
    return
  }

  // -------------------------------------------------------------------------
  // Convert diffs → createUnifiedLzConfigProposal format
  // -------------------------------------------------------------------------
  const toProposalConfig = (diff: ConfigDiff) => ({
    sourceChain: diff.chain,
    targetChain: diff.remoteChain,
    oAppType: (diff.oAppName.includes('Token') ? 'summerToken' : 'summerGovernor') as
      | 'summerToken'
      | 'summerGovernor',
    oAppAddress: diff.oAppAddress,
    directExecution: false as const,
    success: false as const,
    lzEndpointAddress: diff.lzEndpointAddress,
    sendLibraryAddress: diff.sendLibAddress,
    receiveLibraryAddress: diff.receiveLibAddress,
    sendConfigParams: [
      { eid: diff.remoteEid, configType: 1, config: diff.encodedExecutor },
      { eid: diff.remoteEid, configType: 2, config: diff.encodedUln },
    ],
    receiveConfigParams: [{ eid: diff.remoteEid, configType: 2, config: diff.encodedUln }],
  })

  const hubChainConfigs = phaseDiffs
    .filter((d) => d.chain === hubChain)
    .map(toProposalConfig)

  const nonHubChainConfigs = phaseDiffs
    .filter((d) => d.chain !== hubChain)
    .map(toProposalConfig)

  console.log(
    kleur.cyan(
      `\nGenerating proposal: ${hubChainConfigs.length} hub-chain action(s), ${nonHubChainConfigs.length} cross-chain action(s)`,
    ),
  )

  await createUnifiedLzConfigProposal(
    hubChainConfigs,
    nonHubChainConfigs,
    useBummerConfig,
    'dvn-update',
    '',
    undefined,
    undefined,
    undefined,
  )
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
const args = process.argv.slice(2)
const useBummerConfig = args.includes('--bummer')

updateDvnConfig(useBummerConfig).catch((err) => {
  console.error(kleur.red('Error during DVN config update:'))
  console.error(err instanceof Error ? err.message : String(err))
  process.exit(1)
})
