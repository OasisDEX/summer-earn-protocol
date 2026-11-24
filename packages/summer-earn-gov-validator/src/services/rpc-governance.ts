import {
  type Address,
  createPublicClient,
  decodeEventLog,
  fallback,
  type Hex,
  http,
  keccak256,
  parseAbi,
  type PublicClient,
  toBytes,
} from 'viem'
import { base } from 'viem/chains'

import { CHAINS } from '@/config/chains'
import { getPublicClient, VIEM_CHAIN_ENTITIES } from '@/config/rpc'
import { Proposal, ProposalWithCrossChain, SubgraphProposalStatus, Vote } from '@/types/governance'

// Subgraph-free data source: rebuilds the `ProposalWithCrossChain` shape the gov
// subgraph returns from SummerGovernor event logs on the hub chain (Base) over a
// bounded lookback window, plus live view calls (state/votes/quorum/eta).
//
// Logs come from the Etherscan v2 logs API when ETHERSCAN_API_KEY is set (a couple of
// calls for the whole window), otherwise from chunked eth_getLogs. Base produces ~5
// blocks/s, so public RPCs (≈10k-block getLogs limit) need hundreds of calls for a
// 14-day window — set ETHERSCAN_API_KEY or GOV_RPC_URL_BASE for production.
//
// Known gaps versus the subgraph:
// - Only proposals created inside the lookback window are visible.
// - Satellite-chain execution status is not tracked: `crossChainProposals` is always
//   `[]`. Hub-side `chains`/`dstIds` ARE filled from ProposalSentCrossChain logs, and
//   the simulator decodes satellite actions from the hub calldata on its own.

export const HUB_GOVERNOR = '0x4ceee1b6289624d381383c1bb42b118d5f2c3274' as const
export const V1_GOVERNOR = '0xbe5a4dd68c3526f32b454fe28c9909ca0601e9fa' as const
const GOVERNORS = [HUB_GOVERNOR, V1_GOVERNOR] as const

const DEFAULT_LOOKBACK_DAYS = 14
const DEFAULT_LOG_CHUNK = 10_000
// Below this span a failing range is treated as a real error, not a range limit.
const MIN_SPLIT_SPAN = 500n
const MAX_LOG_CALLS = 3_000
const DEFAULT_CHUNK_CONCURRENCY = 6
const MAX_VOTES_PER_PROPOSAL = 100

// Public Base RPCs that accepted ≥2k-block eth_getLogs ranges when probed (Nov 2026).
const LOG_RPC_URLS = [
  'https://base-rpc.publicnode.com',
  'https://base.public.blockpi.network/v1/rpc/public',
  'https://base.rpc.blxrbdn.com',
]

const ETHERSCAN_API = 'https://api.etherscan.io/v2/api'
const ETHERSCAN_PAGE_SIZE = 1_000

export const GOVERNOR_EVENTS_ABI = parseAbi([
  'event ProposalCreated(uint256 proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 voteStart, uint256 voteEnd, string description)',
  'event ProposalExecuted(uint256 proposalId)',
  'event ProposalSentCrossChain(uint256 indexed proposalId, uint32 indexed dstEid)',
  'event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason)',
  'event VoteCastWithParams(address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason, bytes params)',
])

const GOVERNOR_VIEWS_ABI = parseAbi([
  'function state(uint256 proposalId) view returns (uint8)',
  'function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)',
  'function quorum(uint256 timepoint) view returns (uint256)',
  'function proposalEta(uint256 proposalId) view returns (uint256)',
])

// A decoded governor log, independent of where it came from (RPC or Etherscan).
export interface GovernorLog {
  address: string
  blockNumber: bigint
  logIndex: number
  transactionHash: string
  // Block timestamp when the source provides it (Etherscan does, RPC does not).
  timestamp?: bigint
  eventName: string
  args: Record<string, unknown>
}

// OpenZeppelin IGovernor.ProposalState → the four statuses the subgraph emits.
// Active/Defeated/Succeeded/Expired are derived later from timestamps by
// transformProposal, exactly as with subgraph data, so they map to 'Pending' here.
export function mapGovernorState(state: number): SubgraphProposalStatus {
  switch (state) {
    case 2:
      return 'Canceled'
    case 5:
      return 'Queued'
    case 7:
      return 'Executed'
    default:
      return 'Pending'
  }
}

const DST_EID_TO_CHAIN_ID: Record<string, string> = Object.fromEntries(
  CHAINS.map((c) => [c.eID, c.id]),
)

function envInt(name: string, fallbackValue: number): number {
  const raw = process.env[name]
  const parsed = raw ? Number.parseInt(raw, 10) : NaN
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackValue
}

export function decodeGovernorLog(raw: {
  address: string
  topics: Hex[]
  data: Hex
  blockNumber: bigint
  logIndex: number
  transactionHash: string
  timestamp?: bigint
}): GovernorLog | null {
  try {
    const decoded = decodeEventLog({
      abi: GOVERNOR_EVENTS_ABI,
      topics: raw.topics as [Hex, ...Hex[]],
      data: raw.data,
      strict: true,
    })
    return {
      address: raw.address.toLowerCase(),
      blockNumber: raw.blockNumber,
      logIndex: raw.logIndex,
      transactionHash: raw.transactionHash.toLowerCase(),
      timestamp: raw.timestamp,
      eventName: decoded.eventName,
      args: decoded.args as Record<string, unknown>,
    }
  } catch {
    return null // other governor events (ProposalQueued, ProposalCanceled, ...)
  }
}

// ---------------------------------------------------------------------------
// RPC log source
// ---------------------------------------------------------------------------

export type LogFetcher = (fromBlock: bigint, toBlock: bigint) => Promise<GovernorLog[]>

interface CallBudget {
  remaining: number
}

// Fetch one range; if the provider rejects it, split it in half and retry each half.
// Errors on a span already at MIN_SPLIT_SPAN, or once the call budget is spent,
// propagate so a partial scan is never returned (and never cached).
export async function getLogsSplitting(
  fetchLogs: LogFetcher,
  fromBlock: bigint,
  toBlock: bigint,
  budget: CallBudget = { remaining: MAX_LOG_CALLS },
): Promise<GovernorLog[]> {
  if (budget.remaining-- <= 0) {
    throw new Error(`Log scan exceeded ${MAX_LOG_CALLS} RPC calls; configure a better log source`)
  }
  try {
    return await fetchLogs(fromBlock, toBlock)
  } catch (error) {
    if (toBlock - fromBlock < MIN_SPLIT_SPAN || budget.remaining <= 0) throw error
    const mid = fromBlock + (toBlock - fromBlock) / 2n
    const left = await getLogsSplitting(fetchLogs, fromBlock, mid, budget)
    const right = await getLogsSplitting(fetchLogs, mid + 1n, toBlock, budget)
    return [...left, ...right]
  }
}

export async function scanLogs(
  fetchLogs: LogFetcher,
  fromBlock: bigint,
  toBlock: bigint,
  chunk: bigint,
): Promise<GovernorLog[]> {
  const ranges: Array<[bigint, bigint]> = []
  for (let start = fromBlock; start <= toBlock; start += chunk) {
    const end = start + chunk - 1n < toBlock ? start + chunk - 1n : toBlock
    ranges.push([start, end])
  }
  const budget: CallBudget = { remaining: MAX_LOG_CALLS }
  const results: GovernorLog[][] = new Array(ranges.length)
  let next = 0
  const worker = async () => {
    while (next < ranges.length) {
      const i = next++
      results[i] = await getLogsSplitting(fetchLogs, ranges[i][0], ranges[i][1], budget)
    }
  }
  await Promise.all(
    Array.from(
      {
        length: Math.min(
          envInt('GOV_RPC_LOG_CONCURRENCY', DEFAULT_CHUNK_CONCURRENCY),
          ranges.length,
        ),
      },
      worker,
    ),
  )
  return results.flat()
}

let logClient: PublicClient | undefined
function getLogClient(): PublicClient {
  if (logClient) return logClient
  const dedicated = process.env.GOV_RPC_URL_BASE
  const urls = [...(dedicated ? [dedicated] : []), ...LOG_RPC_URLS]
  logClient = createPublicClient({
    chain: VIEM_CHAIN_ENTITIES[base.id],
    transport: fallback(urls.map((url) => http(url, { timeout: 30_000 }))),
  }) as PublicClient
  return logClient
}

function rpcFetcher(client: PublicClient): LogFetcher {
  return async (fromBlock, toBlock) => {
    const logs = await client.request({
      method: 'eth_getLogs',
      params: [
        {
          address: [...GOVERNORS],
          fromBlock: `0x${fromBlock.toString(16)}`,
          toBlock: `0x${toBlock.toString(16)}`,
        },
      ],
    })
    return logs
      .map((l) =>
        decodeGovernorLog({
          address: l.address,
          topics: l.topics as Hex[],
          data: l.data,
          blockNumber: BigInt(l.blockNumber!),
          logIndex: Number(l.logIndex),
          transactionHash: l.transactionHash!,
        }),
      )
      .filter((l): l is GovernorLog => l !== null)
  }
}

// ---------------------------------------------------------------------------
// Etherscan log source
// ---------------------------------------------------------------------------

interface EtherscanLog {
  address: string
  topics: Hex[]
  data: Hex
  blockNumber: string
  timeStamp: string
  logIndex: string
  transactionHash: string
}

async function etherscanLogs(
  apiKey: string,
  fromBlock: bigint,
  toBlock: bigint,
): Promise<GovernorLog[]> {
  const out: GovernorLog[] = []
  for (const address of GOVERNORS) {
    for (let page = 1; ; page++) {
      const url =
        `${ETHERSCAN_API}?chainid=${base.id}&module=logs&action=getLogs&address=${address}` +
        `&fromBlock=${fromBlock}&toBlock=${toBlock}&page=${page}&offset=${ETHERSCAN_PAGE_SIZE}` +
        `&apikey=${apiKey}`
      const response = await fetch(url, { cache: 'no-store' })
      if (!response.ok) throw new Error(`Etherscan getLogs HTTP ${response.status}`)
      const body = (await response.json()) as {
        status: string
        message: string
        result: EtherscanLog[] | string
      }
      // status "0" + "No records found" is an empty page, anything else is an error.
      if (body.status !== '1') {
        if (body.message?.startsWith('No records found')) break
        throw new Error(`Etherscan getLogs failed: ${body.message} ${String(body.result)}`)
      }
      const rows = body.result as EtherscanLog[]
      for (const row of rows) {
        const decoded = decodeGovernorLog({
          address: row.address,
          topics: row.topics.filter(Boolean),
          data: row.data,
          blockNumber: BigInt(row.blockNumber),
          logIndex: row.logIndex === '0x' ? 0 : Number(row.logIndex),
          transactionHash: row.transactionHash,
          timestamp: BigInt(row.timeStamp),
        })
        if (decoded) out.push(decoded)
      }
      if (rows.length < ETHERSCAN_PAGE_SIZE) break
    }
  }
  return out
}

// ---------------------------------------------------------------------------
// Window + assembly
// ---------------------------------------------------------------------------

// First block with timestamp >= target, by binary search. Block time on Base is not
// constant (2s until Nov 2026, ~0.2s after), so it cannot be derived from a rate.
export async function findBlockAtOrAfter(
  getTimestamp: (block: bigint) => Promise<bigint>,
  target: bigint,
  latest: bigint,
): Promise<bigint> {
  let lo = 0n
  let hi = latest
  while (lo < hi) {
    const mid = (lo + hi) / 2n
    if ((await getTimestamp(mid)) < target) lo = mid + 1n
    else hi = mid
  }
  return lo
}

async function getWindow(client: PublicClient) {
  const latest = await client.getBlock()
  const lookbackDays = envInt('GOV_RPC_LOOKBACK_DAYS', DEFAULT_LOOKBACK_DAYS)
  const target = latest.timestamp - BigInt(lookbackDays * 86_400)
  const fromBlock = await findBlockAtOrAfter(
    async (n) => (await client.getBlock({ blockNumber: n })).timestamp,
    target,
    latest.number,
  )
  return { fromBlock, toBlock: latest.number }
}

export interface ScannedProposal {
  proposal: Omit<
    Proposal,
    'status' | 'eta' | 'quorum' | 'forVotes' | 'againstVotes' | 'abstainVotes' | 'createdAt'
  >
  blockNumber: bigint
  timestamp?: bigint
}

const isVoteEvent = (l: GovernorLog) =>
  l.eventName === 'VoteCast' || l.eventName === 'VoteCastWithParams'

// Turn raw logs of ONE governor into proposal skeletons (with their newest votes),
// joining ProposalSentCrossChain to its hub proposal the way the subgraph does: via the
// ProposalExecuted log emitted in the same transaction.
export function buildProposalsFromLogs(logs: GovernorLog[], governor: string): ScannedProposal[] {
  const own = logs.filter((l) => l.address === governor.toLowerCase())
  const proposals = new Map<string, ScannedProposal>()
  const executedByTx = new Map<string, string>()

  for (const log of own) {
    if (log.eventName === 'ProposalCreated') {
      const a = log.args as {
        proposalId: bigint
        targets: readonly string[]
        values: readonly bigint[]
        calldatas: readonly Hex[]
        voteStart: bigint
        voteEnd: bigint
        description: string
      }
      const id = a.proposalId.toString()
      proposals.set(id, {
        blockNumber: log.blockNumber,
        timestamp: log.timestamp,
        proposal: {
          id,
          governor: governor.toLowerCase(),
          targets: a.targets.map((t) => t.toLowerCase()),
          values: a.values.map((v) => v.toString()),
          calldatas: [...a.calldatas],
          description: a.description,
          descriptionHash: keccak256(toBytes(a.description)),
          chains: [],
          dstIds: [],
          voteStart: a.voteStart.toString(),
          voteEnd: a.voteEnd.toString(),
          votes: [],
          salt: '0x',
        },
      })
    } else if (log.eventName === 'ProposalExecuted') {
      executedByTx.set(log.transactionHash, String(log.args.proposalId))
    }
  }

  for (const log of own) {
    if (log.eventName !== 'ProposalSentCrossChain') continue
    const hubId = executedByTx.get(log.transactionHash)
    const entry = hubId ? proposals.get(hubId) : undefined
    const chainId = DST_EID_TO_CHAIN_ID[String(log.args.dstEid)]
    if (!entry || !chainId) continue
    entry.proposal.chains.push(chainId)
    entry.proposal.dstIds!.push(String(log.args.proposalId))
  }

  for (const entry of proposals.values()) {
    entry.proposal.votes = buildVotesFromLogs(own, entry.proposal.id)
  }

  return [...proposals.values()].sort((x, y) => (x.blockNumber > y.blockNumber ? -1 : 1))
}

// Newest MAX_VOTES_PER_PROPOSAL non-zero votes for a proposal (matching the subgraph
// query: first 100, timestamp desc, votes > 0). When the log source has no timestamp,
// the field temporarily holds `block:<n>` and hydrate() resolves it.
export function buildVotesFromLogs(logs: GovernorLog[], proposalId: string): Vote[] {
  return logs
    .filter((l) => isVoteEvent(l) && String(l.args.proposalId) === proposalId)
    .filter((l) => (l.args.weight as bigint) > 0n)
    .sort((a, b) =>
      a.blockNumber === b.blockNumber
        ? b.logIndex - a.logIndex
        : a.blockNumber > b.blockNumber
          ? -1
          : 1,
    )
    .slice(0, MAX_VOTES_PER_PROPOSAL)
    .map((l) => ({
      id: `${l.transactionHash}-${l.logIndex}`,
      voter: String(l.args.voter).toLowerCase(),
      support: Number(l.args.support),
      // Event weight is the weight the governor actually counted for this vote.
      votes: (l.args.weight as bigint).toString(),
      reason: String(l.args.reason ?? ''),
      timestamp: l.timestamp !== undefined ? l.timestamp.toString() : `block:${l.blockNumber}`,
    }))
}

async function blockTimestamps(client: PublicClient, blocks: bigint[]) {
  const unique = [...new Set(blocks)]
  const fetched = await Promise.all(unique.map((n) => client.getBlock({ blockNumber: n })))
  return new Map(fetched.map((b) => [b.number, b.timestamp]))
}

async function hydrate(client: PublicClient, scanned: ScannedProposal[]): Promise<Proposal[]> {
  // Resolve any timestamps the log source did not provide (RPC path).
  const pendingVoteBlocks = scanned.flatMap((s) =>
    s.proposal.votes
      .filter((v) => v.timestamp.startsWith('block:'))
      .map((v) => BigInt(v.timestamp.slice(6))),
  )
  const missing = scanned.filter((s) => s.timestamp === undefined).map((s) => s.blockNumber)
  const ts = await blockTimestamps(client, [...missing, ...pendingVoteBlocks])

  return Promise.all(
    scanned.map(async ({ proposal, blockNumber, timestamp }) => {
      const id = BigInt(proposal.id)
      const governor = proposal.governor as Address
      const createdAt = timestamp ?? ts.get(blockNumber)!
      const [state, votes, quorum, eta] = await client.multicall({
        allowFailure: false,
        contracts: [
          { address: governor, abi: GOVERNOR_VIEWS_ABI, functionName: 'state', args: [id] },
          { address: governor, abi: GOVERNOR_VIEWS_ABI, functionName: 'proposalVotes', args: [id] },
          // Same timepoint the subgraph uses; a future timepoint would revert.
          {
            address: governor,
            abi: GOVERNOR_VIEWS_ABI,
            functionName: 'quorum',
            args: [createdAt - 1n],
          },
          { address: governor, abi: GOVERNOR_VIEWS_ABI, functionName: 'proposalEta', args: [id] },
        ],
      })
      return {
        ...proposal,
        votes: proposal.votes.map((v) =>
          v.timestamp.startsWith('block:')
            ? { ...v, timestamp: (ts.get(BigInt(v.timestamp.slice(6))) ?? 0n).toString() }
            : v,
        ),
        status: mapGovernorState(state),
        createdAt: createdAt.toString(),
        quorum: quorum.toString(),
        againstVotes: votes[0].toString(),
        forVotes: votes[1].toString(),
        abstainVotes: votes[2].toString(),
        eta: eta.toString(),
      }
    }),
  )
}

// Fetch every governor log (both governors) in [fromBlock, toBlock].
export async function fetchGovernorLogs(
  fromBlock: bigint,
  toBlock: bigint,
): Promise<GovernorLog[]> {
  const apiKey = process.env.ETHERSCAN_API_KEY
  if (apiKey && process.env.GOV_LOG_SOURCE !== 'rpc') {
    try {
      return await etherscanLogs(apiKey, fromBlock, toBlock)
    } catch (error) {
      // e.g. a free-tier key: Etherscan v2 rejects Base ("Free API access is not
      // supported for this chain"). Fall back to RPC rather than failing the page.
      console.warn('Etherscan log fetch failed, falling back to RPC:', error)
    }
  }
  const chunk = BigInt(envInt('GOV_RPC_LOG_CHUNK', DEFAULT_LOG_CHUNK))
  return scanLogs(rpcFetcher(getLogClient()), fromBlock, toBlock, chunk)
}

// Exposed for verification: build proposals for one governor from an explicit range.
export async function scanGovernorRange(
  governor: Address,
  fromBlock: bigint,
  toBlock: bigint,
): Promise<Proposal[]> {
  const logs = await fetchGovernorLogs(fromBlock, toBlock)
  return hydrate(getPublicClient(base.id), buildProposalsFromLogs(logs, governor))
}

// One scan for both governors; callers partition the result.
export async function fetchAllGovernanceProposals(): Promise<{
  v1: ProposalWithCrossChain[]
  v2: ProposalWithCrossChain[]
}> {
  const client = getPublicClient(base.id)
  const { fromBlock, toBlock } = await getWindow(client)
  const logs = await fetchGovernorLogs(fromBlock, toBlock)
  const [v2, v1] = await Promise.all(
    [HUB_GOVERNOR, V1_GOVERNOR].map((g) => hydrate(client, buildProposalsFromLogs(logs, g))),
  )
  const wrap = (ps: Proposal[]) =>
    ps.map((baseProposal) => ({ baseProposal, crossChainProposals: [] }))
  return { v1: wrap(v1), v2: wrap(v2) }
}

export async function fetchAllProposals(
  params: { isV1: boolean } = { isV1: false },
): Promise<ProposalWithCrossChain[]> {
  const all = await fetchAllGovernanceProposals()
  return params.isV1 ? all.v1 : all.v2
}

// `null` means the proposal is not on this governor inside the lookback window.
// Errors propagate so a transient failure is not cached as "not found".
export async function fetchProposalById(
  id: string,
  isV1: boolean = false,
): Promise<ProposalWithCrossChain | null> {
  const list = await fetchAllProposals({ isV1 })
  return list.find((p) => p.baseProposal.id === id) ?? null
}
