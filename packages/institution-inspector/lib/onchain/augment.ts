import { type Address, createPublicClient, fallback, http } from 'viem'
import { CHAIN_RPC_URLS, viemChainFor } from '../../config/chains'
import { type GraphEdge, type GraphNode, nodeId } from '../graph-schema'
import { PAM_ABI, REGISTRY_ABI, ROUNDS_VAULT_REGISTRY_ABI } from './abis'
import { institutionBytes32, resolveRoleHash } from './roles'

export interface AugmentInput {
  network: string
  nodes: GraphNode[]
  edges: GraphEdge[]
  pamByInstitution: Record<string, string>
  registries: { v1?: string; v2?: string; roundsVault?: string }
}

export interface OnchainMeta {
  fetched: boolean
  blockNumber?: string
  rpcOk?: boolean
}

const lc = (a?: string) => (a ?? '').toLowerCase()
// Extract a successful multicall result (allowFailure mode), else undefined.
const ok = (r: any): any => (r && r.status === 'success' ? r.result : undefined)

/**
 * Pass B: verify the config-derived graph against on-chain state and annotate in place.
 * - registry: confirm each institution exists() + getInstitution() wiring (drift on mismatch)
 * - roles: PAM.hasRole for each declared role edge (verifiedOnChain / drift)
 * - rounds vaults: reconcile input/output against RoundsVaultRegistry
 * Degrades gracefully: on RPC failure returns { fetched: false } and leaves the config graph intact.
 */
export async function augmentOnchain(input: AugmentInput): Promise<OnchainMeta> {
  const { network, nodes, edges, pamByInstitution, registries } = input
  const chain = viemChainFor(network)
  if (!chain) return { fetched: false }
  const rpcs = CHAIN_RPC_URLS[chain.id] ?? []
  if (rpcs.length === 0) return { fetched: false }

  const client = createPublicClient({
    chain,
    transport: rpcs.length > 1 ? fallback(rpcs.map((u) => http(u))) : http(rpcs[0]),
  })

  let blockNumber: bigint
  try {
    blockNumber = await client.getBlockNumber()
  } catch {
    return { fetched: false, rpcOk: false }
  }

  const byId = new Map(nodes.map((n) => [n.id, n]))
  const institutions = nodes.filter((n) => n.type === 'institution')

  // --- Registry verification -------------------------------------------------
  const regV2 = registries.v2 as Address | undefined
  const regNode = byId.get(nodeId.registry('V2'))
  if (regV2) {
    const ids = institutions.map((n) => institutionBytes32(n.data.institutionId!))
    const calls = institutions.flatMap((_, i) => [
      { address: regV2, abi: REGISTRY_ABI, functionName: 'exists', args: [ids[i]] } as const,
      { address: regV2, abi: REGISTRY_ABI, functionName: 'getInstitution', args: [ids[i]] } as const,
    ])
    const res = await client.multicall({ contracts: calls as any, allowFailure: true })
    institutions.forEach((instNode, i) => {
      const inst = instNode.data.institutionId!
      const exists = Boolean(ok(res[i * 2]))
      instNode.data.existsOnChain = exists
      instNode.data.source = 'config+onchain'
      if (exists && regNode) {
        edges.push({ id: `eonc-reg-${i}`, type: 'system', source: instNode.id, target: regNode.id, data: { verifiedOnChain: true } })
      }
      const wiring = ok(res[i * 2 + 1])
      if (exists && wiring) {
        const checks: Array<[string, string]> = [
          [nodeId.system(inst, 'ConfigurationManager'), wiring.configurationManager],
          [nodeId.system(inst, 'ProtocolAccessManager'), wiring.protocolAccessManager],
          [nodeId.system(inst, 'AdmiralsQuarters'), wiring.admiralsQuarters],
        ]
        for (const [sysNodeId, onchainAddr] of checks) {
          const n = byId.get(sysNodeId)
          if (!n) continue
          n.data.source = 'config+onchain'
          if (lc(n.data.address) !== lc(onchainAddr)) {
            n.data.drift = true
            n.data.driftDetail = `registry has ${onchainAddr}`
          }
        }
      }
    })
  }

  // --- Role verification (PAM.hasRole) --------------------------------------
  const roleEdges = edges.filter((e) => e.type === 'hasRole' && e.data?.role)
  type Job = { edge: GraphEdge; pam: Address; roleHash: `0x${string}`; holder: Address }
  const jobs: Job[] = []
  for (const e of roleEdges) {
    const inst = e.target.split(':')[1]
    const pam = pamByInstitution[inst] as Address | undefined
    const holder = byId.get(e.source)?.data.address as Address | undefined
    if (!pam || !holder) continue
    // Contract-specific roles (CURATOR_ROLE) target a fleet commander node.
    const targetNode = byId.get(e.target)
    const contractTarget = targetNode?.type === 'fleetCommander' ? (targetNode.data.address as Address) : undefined
    const roleHash = resolveRoleHash(e.data!.role!, contractTarget)
    if (!roleHash) continue
    jobs.push({ edge: e, pam, roleHash, holder })
  }
  if (jobs.length > 0) {
    const res = await client.multicall({
      contracts: jobs.map((j) => ({ address: j.pam, abi: PAM_ABI, functionName: 'hasRole', args: [j.roleHash, j.holder] })) as any,
      allowFailure: true,
    })
    jobs.forEach((j, i) => {
      const has = Boolean(ok(res[i]))
      j.edge.data = { ...j.edge.data, verifiedOnChain: has, drift: !has }
    })
  }

  // --- RoundsVault reconcile -------------------------------------------------
  const rvReg = registries.roundsVault as Address | undefined
  if (rvReg) {
    const fcNodes = nodes.filter((n) => n.type === 'fleetCommander' && n.data.address)
    const res = await client.multicall({
      contracts: fcNodes.map((fc) => ({ address: rvReg, abi: ROUNDS_VAULT_REGISTRY_ABI, functionName: 'getPairByTarget', args: [fc.data.address as Address] })) as any,
      allowFailure: true,
    })
    fcNodes.forEach((fc, i) => {
      const pair = ok(res[i])
      if (!pair) return
      const [, instId, fleet] = fc.id.split(':')
      for (const [kind, want] of [
        ['roundsVaultInput', pair.inputVault],
        ['roundsVaultOutput', pair.outputVault],
      ] as const) {
        const nid = kind === 'roundsVaultInput' ? nodeId.roundsVaultInput(instId, fleet) : nodeId.roundsVaultOutput(instId, fleet)
        const n = byId.get(nid)
        if (!n) continue
        n.data.source = 'config+onchain'
        if (lc(n.data.address) !== lc(want)) {
          n.data.drift = true
          n.data.driftDetail = `registry has ${want}`
        }
      }
    })
  }

  return { fetched: true, blockNumber: blockNumber.toString(), rpcOk: true }
}
