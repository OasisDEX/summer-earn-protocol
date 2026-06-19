import { z } from 'zod'

/**
 * Normalized graph model shared by the generator (scripts/) and the viewer (components/).
 * Single source of truth — no duplication between producer and consumer.
 */

export const NODE_TYPES = [
  'institution',
  'fleet',
  'fleetCommander',
  'bufferArk',
  'ark',
  'roundsVaultInput',
  'roundsVaultOutput',
  'systemContract',
  'timelock',
  'roleHolder',
] as const
export type NodeType = (typeof NODE_TYPES)[number]

export const EDGE_TYPES = [
  'contains', // institution -> fleet
  'system', // institution -> system contract
  'deploys', // fleet -> fleetCommander
  'buffer', // fleetCommander -> bufferArk
  'ark', // fleetCommander -> ark
  'roundsInput', // fleetCommander -> roundsVaultInput
  'roundsOutput', // fleetCommander -> roundsVaultOutput
  'governs', // timelock -> target (carries role)
  'hasRole', // roleHolder -> target (carries role)
] as const
export type EdgeType = (typeof EDGE_TYPES)[number]

export const DataSource = z.enum(['config', 'onchain', 'config+onchain'])
export type DataSource = z.infer<typeof DataSource>

const AddressLike = z.string().regex(/^0x[0-9a-fA-F]{40}$/)

export const GraphNodeDataSchema = z.object({
  label: z.string(),
  source: DataSource.default('config'),
  // common contract fields
  address: AddressLike.optional(),
  kind: z.string().optional(), // systemContract/timelock sub-kind (e.g. "ProtocolAccessManager")
  contractName: z.string().optional(), // from Ignition artifact (e.g. "AaveV3Ark")
  protocol: z.string().optional(), // inferred protocol (e.g. "AaveV3")
  futureId: z.string().optional(), // Ignition futureId
  // institution / fleet
  institutionId: z.string().optional(),
  bytes32Id: z.string().optional(),
  fleetName: z.string().optional(),
  asset: z.string().optional(),
  arkCount: z.number().optional(),
  // timelock
  delaySeconds: z.number().optional(),
  // role list attached to a contract node (for quick display)
  roles: z.array(z.object({ role: z.string(), holder: AddressLike })).optional(),
  // on-chain verification flags
  existsOnChain: z.boolean().optional(),
  drift: z.boolean().optional(),
  driftDetail: z.string().optional(),
})
export type GraphNodeData = z.infer<typeof GraphNodeDataSchema>

export const GraphNodeSchema = z.object({
  id: z.string(),
  type: z.enum(NODE_TYPES),
  data: GraphNodeDataSchema,
})
export type GraphNode = z.infer<typeof GraphNodeSchema>

export const GraphEdgeDataSchema = z
  .object({
    role: z.string().optional(),
    verifiedOnChain: z.boolean().optional(),
    drift: z.boolean().optional(),
  })
  .optional()

export const GraphEdgeSchema = z.object({
  id: z.string(),
  type: z.enum(EDGE_TYPES),
  source: z.string(),
  target: z.string(),
  data: GraphEdgeDataSchema,
})
export type GraphEdge = z.infer<typeof GraphEdgeSchema>

export const GraphFileSchema = z.object({
  schemaVersion: z.literal(1),
  generatedAt: z.string(),
  network: z.string(),
  chainId: z.number(),
  env: z.enum(['production', 'staging']),
  onchain: z.object({
    fetched: z.boolean(),
    blockNumber: z.string().optional(),
    rpcOk: z.boolean().optional(),
  }),
  nodes: z.array(GraphNodeSchema),
  edges: z.array(GraphEdgeSchema),
})
export type GraphFile = z.infer<typeof GraphFileSchema>

// Deterministic node id helpers — used by both passes so on-chain augmentation
// merges into config nodes by id.
export const nodeId = {
  institution: (inst: string) => `inst:${inst}`,
  system: (inst: string, kind: string) => `sys:${inst}:${kind}`,
  timelock: (inst: string, kind: string) => `tl:${inst}:${kind}`,
  fleet: (inst: string, fleet: string) => `fleet:${inst}:${fleet}`,
  fleetCommander: (inst: string, fleet: string) => `fc:${inst}:${fleet}`,
  bufferArk: (inst: string, fleet: string) => `buf:${inst}:${fleet}`,
  ark: (inst: string, fleet: string, i: number) => `ark:${inst}:${fleet}:${i}`,
  roundsVaultInput: (inst: string, fleet: string) => `rvin:${inst}:${fleet}`,
  roundsVaultOutput: (inst: string, fleet: string) => `rvout:${inst}:${fleet}`,
  registry: (kind: string) => `registry:${kind}`,
  roleHolder: (addr: string) => `role:${addr.toLowerCase()}`,
}
