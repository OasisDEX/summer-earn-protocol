import fs from 'node:fs'
import path from 'node:path'
import { type GraphEdge, type GraphNode, nodeId } from '../lib/graph-schema'
import { loadIgnitionMetadata, type ContractMeta } from './ignition-metadata'

export type Env = 'production' | 'staging'

const CHAIN_IDS: Record<string, number> = {
  base: 8453,
  arbitrum: 42161,
  mainnet: 1,
  sonic: 146,
  hyperliquid: 999,
  sepolia_mainnet: 11155111,
}

const SYSTEM_CORE_KINDS: Record<string, string> = {
  tipJar: 'TipJar',
  configurationManager: 'ConfigurationManager',
  harborCommand: 'HarborCommand',
  admiralsQuarters: 'AdmiralsQuarters',
  raft: 'Raft',
}

function readJson(p: string): any | undefined {
  if (!fs.existsSync(p)) return undefined
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'))
  } catch {
    return undefined
  }
}

function indexFile(env: Env): string {
  return env === 'staging' ? 'index.test.json' : 'index.json'
}

/** Map fleetName -> assetSymbol by reading the institution's fleet config files. */
function readFleetAssets(institutionDir: string, network: string): Record<string, string> {
  const out: Record<string, string> = {}
  const fleetsDir = path.join(institutionDir, 'fleets')
  if (!fs.existsSync(fleetsDir)) return out
  for (const f of fs.readdirSync(fleetsDir)) {
    if (!f.endsWith('.json')) continue
    const cfg = readJson(path.join(fleetsDir, f))
    if (cfg?.fleetName && (cfg.network === network || !cfg.network)) {
      out[cfg.fleetName] = cfg.assetSymbol ?? out[cfg.fleetName]
    }
  }
  return out
}

export interface PassAResult {
  chainId: number
  nodes: GraphNode[]
  edges: GraphEdge[]
  /** institutionId -> PAM address, for Pass B role checks. */
  pamByInstitution: Record<string, string>
  registries: { v1?: string; v2?: string; roundsVault?: string }
}

export function buildConfigGraph(deploymentRoot: string, network: string, env: Env): PassAResult {
  const chainId = CHAIN_IDS[network]
  if (!chainId) throw new Error(`Unknown network: ${network}`)

  const configRoot = path.join(deploymentRoot, 'config')
  const institutionsRoot = path.join(configRoot, 'institutions')
  const ignition = loadIgnitionMetadata(deploymentRoot, chainId)

  const nodes = new Map<string, GraphNode>()
  const edges: GraphEdge[] = []
  const pamByInstitution: Record<string, string> = {}
  let edgeSeq = 0
  const addEdge = (e: Omit<GraphEdge, 'id'>) => edges.push({ id: `e${edgeSeq++}`, ...e })
  const meta = (addr?: string): ContractMeta | undefined =>
    addr ? ignition.get(addr.toLowerCase()) : undefined

  // Base config: registries for this network.
  const baseConfig = readJson(path.join(configRoot, indexFile(env)))
  const baseCore = baseConfig?.[network]?.deployedContracts?.core ?? {}
  const registries = {
    v1: baseCore.institutionalVaultRegistry?.address,
    v2: baseCore.institutionalVaultRegistryV2?.address,
    roundsVault: baseCore.roundsVaultRegistry?.address,
  }
  if (registries.v2) {
    nodes.set(nodeId.registry('V2'), {
      id: nodeId.registry('V2'),
      type: 'systemContract',
      data: {
        label: 'InstitutionalVaultRegistry V2',
        kind: 'Registry',
        address: registries.v2,
        source: 'config',
      },
    })
  }

  const institutionIds = fs
    .readdirSync(institutionsRoot, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => d.name)

  for (const inst of institutionIds) {
    const instDir = path.join(institutionsRoot, inst)
    const cfg = readJson(path.join(instDir, indexFile(env)))
    const net = cfg?.[network]
    if (!net) continue // institution has no entry for this network/env

    const gov = net.deployedContracts?.gov ?? {}
    const core = net.deployedContracts?.core ?? {}
    const pam = gov.protocolAccessManager?.address
    if (pam) pamByInstitution[inst] = pam

    // Institution node
    const instNode = nodeId.institution(inst)
    nodes.set(instNode, {
      id: instNode,
      type: 'institution',
      data: { label: inst, institutionId: inst, source: 'config' },
    })

    // System contracts
    if (pam) {
      const id = nodeId.system(inst, 'ProtocolAccessManager')
      nodes.set(id, {
        id,
        type: 'systemContract',
        data: { label: 'PAM', kind: 'ProtocolAccessManager', address: pam, source: 'config' },
      })
      addEdge({ type: 'system', source: instNode, target: id })
    }
    for (const [key, kind] of Object.entries(SYSTEM_CORE_KINDS)) {
      const addr = core[key]?.address
      if (!addr) continue
      const id = nodeId.system(inst, kind)
      nodes.set(id, {
        id,
        type: 'systemContract',
        data: { label: kind, kind, address: addr, source: 'config' },
      })
      addEdge({ type: 'system', source: instNode, target: id })
    }

    // Timelocks (only when addresses recorded)
    const delays = net.timelock ?? {}
    const timelockDefs: Array<[string, string, string, number | undefined]> = [
      ['governorTimelock', 'GovernorTimelock', 'GOVERNOR_ROLE', delays.governorDelay],
      ['curatorTimelock', 'CuratorTimelock', 'CURATOR_ROLE', delays.curatorDelay],
      ['treasuryTimelock', 'TreasuryTimelock', 'TREASURY_ROLE', delays.treasuryDelay],
    ]
    const pamSysId = nodeId.system(inst, 'ProtocolAccessManager')
    for (const [key, kind, role, delay] of timelockDefs) {
      const addr = gov[key]?.address
      if (!addr) continue
      const id = nodeId.timelock(inst, kind)
      nodes.set(id, {
        id,
        type: 'timelock',
        data: {
          label: kind,
          kind,
          address: addr,
          delaySeconds: typeof delay === 'number' ? delay : undefined,
          source: 'config',
        },
      })
      if (pam) addEdge({ type: 'governs', source: id, target: pamSysId, data: { role } })
    }

    // Institution-level role holders (config-declared)
    const roleHolderEdge = (addr: string, role: string) => {
      if (!addr || !pam) return
      const id = nodeId.roleHolder(addr)
      if (!nodes.has(id)) {
        nodes.set(id, {
          id,
          type: 'roleHolder',
          data: { label: `${addr.slice(0, 6)}…${addr.slice(-4)}`, address: addr, source: 'config' },
        })
      }
      addEdge({
        type: 'hasRole',
        source: id,
        target: pamSysId,
        data: { role, verifiedOnChain: false },
      })
    }
    for (const g of net.governor ?? []) roleHolderEdge(g, 'GOVERNOR_ROLE')
    for (const g of net.guardian ?? []) roleHolderEdge(g, 'GUARDIAN_ROLE')
    if (net.superKeeper) roleHolderEdge(net.superKeeper, 'SUPER_KEEPER_ROLE')
    for (const w of net.whitelistManagers ?? []) roleHolderEdge(w, 'WHITELIST_MANAGER_ROLE')

    // Fleets
    const fleetAssets = readFleetAssets(instDir, network)
    const fleets = net.fleets ?? {}
    for (const [fleetName, f] of Object.entries<any>(fleets)) {
      const fleetNode = nodeId.fleet(inst, fleetName)
      const arks: string[] = Array.isArray(f.arks) ? f.arks : []
      nodes.set(fleetNode, {
        id: fleetNode,
        type: 'fleet',
        data: {
          label: fleetName,
          fleetName,
          asset: fleetAssets[fleetName],
          arkCount: arks.length,
          source: 'config',
        },
      })
      addEdge({ type: 'contains', source: instNode, target: fleetNode })

      if (f.fleetCommander) {
        const fcId = nodeId.fleetCommander(inst, fleetName)
        const fcMeta = meta(f.fleetCommander)
        nodes.set(fcId, {
          id: fcId,
          type: 'fleetCommander',
          data: {
            label: 'FleetCommander',
            address: f.fleetCommander,
            contractName: fcMeta?.contractName,
            futureId: fcMeta?.futureId,
            source: 'config',
          },
        })
        addEdge({ type: 'deploys', source: fleetNode, target: fcId })

        if (f.bufferArk) {
          const id = nodeId.bufferArk(inst, fleetName)
          nodes.set(id, {
            id,
            type: 'bufferArk',
            data: {
              label: 'BufferArk',
              address: f.bufferArk,
              contractName: meta(f.bufferArk)?.contractName,
              source: 'config',
            },
          })
          addEdge({ type: 'buffer', source: fcId, target: id })
        }
        arks.forEach((arkAddr, i) => {
          const id = nodeId.ark(inst, fleetName, i)
          const m = meta(arkAddr)
          nodes.set(id, {
            id,
            type: 'ark',
            data: {
              label: m?.contractName ?? 'Ark',
              address: arkAddr,
              contractName: m?.contractName,
              protocol: m?.protocol,
              futureId: m?.futureId,
              source: 'config',
            },
          })
          addEdge({ type: 'ark', source: fcId, target: id })
        })
        if (f.roundsVaultInput) {
          const id = nodeId.roundsVaultInput(inst, fleetName)
          nodes.set(id, {
            id,
            type: 'roundsVaultInput',
            data: { label: 'RoundsVaultInput', address: f.roundsVaultInput, source: 'config' },
          })
          addEdge({ type: 'roundsInput', source: fcId, target: id })
        }
        if (f.roundsVaultOutput) {
          const id = nodeId.roundsVaultOutput(inst, fleetName)
          nodes.set(id, {
            id,
            type: 'roundsVaultOutput',
            data: { label: 'RoundsVaultOutput', address: f.roundsVaultOutput, source: 'config' },
          })
          addEdge({ type: 'roundsOutput', source: fcId, target: id })
        }

        // Fleet-level curators (config-declared CURATOR_ROLE on this fleet commander)
        for (const c of net.curators ?? []) {
          if (!c) continue
          const rid = nodeId.roleHolder(c)
          if (!nodes.has(rid)) {
            nodes.set(rid, {
              id: rid,
              type: 'roleHolder',
              data: { label: `${c.slice(0, 6)}…${c.slice(-4)}`, address: c, source: 'config' },
            })
          }
          addEdge({
            type: 'hasRole',
            source: rid,
            target: fcId,
            data: { role: 'CURATOR_ROLE', verifiedOnChain: false },
          })
        }
      }
    }
  }

  return { chainId, nodes: [...nodes.values()], edges, pamByInstitution, registries }
}
