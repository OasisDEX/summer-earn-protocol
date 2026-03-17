import { createPublicClient, http, type Address, formatUnits, Transport, fallback } from 'viem'
import { arbitrum, base, hyperliquid, mainnet, sonic } from 'viem/chains'
import { RWA_ORACLE_ABI, ORACLE_REGISTRY_ABI } from './constants'
import { DeploymentFileSchema } from './schemas'
import { getOffchainFetcher } from './fetchers'
import deploymentsJson from './deployments.json'
import { CHAIN_RPC_URLS } from '@/config/chains'

export { CHAIN_RPC_URLS }

export type OracleStatus = 'healthy' | 'warning' | 'stale'

export interface TickerStats {
  ticker: string
  onChainPrice: number
  onChainTimestamp: number
  offChainPrice: number
  offChainTimestamp: number
  oracleStatus: OracleStatus
  statusDetail: string
  oracleAddress: Address
  assetAddress: Address
  threshold: number
  description: string
  version: number
  latestRoundId: bigint
  nonce: bigint
  owner: Address
  signers: Address[]
  history: { price: number; timestamp: number }[]
}

export type NetworkType = 'base' | 'arbitrum' | 'mainnet' | 'sonic' | 'hyperliquid'

export const NETWORK_TO_CHAIN_ID: Record<NetworkType, number> = {
  base: base.id,
  arbitrum: arbitrum.id,
  mainnet: mainnet.id,
  sonic: sonic.id,
  hyperliquid: 999, // Hyperliquid placeholder
}

export const selectedNetworkToViemNetwork = (network: NetworkType) => {
  switch (network) {
    case 'base':
      return base
    case 'arbitrum':
      return arbitrum
    case 'mainnet':
      return mainnet
    case 'sonic':
      return sonic
    case 'hyperliquid':
      return hyperliquid
  }
}

function createRpcTransport(rpcUrls: string[]): Transport {
  if (rpcUrls.length === 0) return http()
  if (rpcUrls.length === 1) return http(rpcUrls[0])
  return fallback(rpcUrls.map((url) => http(url)))
}

const deployments = DeploymentFileSchema.parse(deploymentsJson)

export async function fetchOracleStats(selectedNetwork: NetworkType): Promise<TickerStats[]> {
  const chain = selectedNetworkToViemNetwork(selectedNetwork)
  const rpcUrls = CHAIN_RPC_URLS[chain.id] || []
  const chainId = chain.id

  const deploymentEntry = Object.values(deployments).find((d) => d.chainId === chainId)
  const registryAddress = deploymentEntry?.oracleRegistry as Address | undefined
  const oracles = deploymentEntry?.oracles ?? []

  if (
    !registryAddress ||
    registryAddress === '0x0000000000000000000000000000000000000000' ||
    oracles.length === 0
  ) {
    return []
  }

  const publicClient = createPublicClient({
    chain,
    transport: createRpcTransport(rpcUrls),
  })

  // Multicall: registry + all oracle properties (allowFailure: true)
  const multicallContracts = oracles.flatMap((entry) => [
    {
      address: registryAddress,
      abi: ORACLE_REGISTRY_ABI,
      functionName: 'oracleToAsset' as const,
      args: [entry.oracleAddress as Address],
    },
    {
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'latestRoundData' as const,
    },
    {
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'threshold' as const,
    },
    {
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'description' as const,
    },
    {
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'version' as const,
    },
    {
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'latestRoundId' as const,
    },
    {
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'nonce' as const,
    },
    {
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'owner' as const,
    },
    // Signers (fetching up to 5)
    ...[0, 1, 2, 3, 4].map((idx) => ({
      address: entry.oracleAddress as Address,
      abi: RWA_ORACLE_ABI,
      functionName: 'signersList' as const,
      args: [BigInt(idx)],
    })),
  ])

  const onChainResults = await publicClient.multicall({
    contracts: multicallContracts,
    allowFailure: true,
  })

  // Offchain: Promise.allSettled per oracle so one failure does not fail the rest
  const offchainSettled = await Promise.allSettled(
    oracles.map(async (entry) => {
      const fetcher = getOffchainFetcher(entry.type, entry.subtype)
      if (!fetcher) return null

      let offchainTicker = entry.ticker
      if (entry.ticker === 'CRDT') offchainTicker = 'CRDYX'
      if (entry.ticker === 'EPXC') offchainTicker = 'WTPIX'

      return fetcher(offchainTicker)
    }),
  )

  const filtered: TickerStats[] = []
  const CALLS_PER_ORACLE = 13

  for (let i = 0; i < oracles.length; i++) {
    const entry = oracles[i]
    const baseIdx = i * CALLS_PER_ORACLE

    const assetResult = onChainResults[baseIdx]
    const roundResult = onChainResults[baseIdx + 1]
    const thresholdResult = onChainResults[baseIdx + 2]
    const descriptionResult = onChainResults[baseIdx + 3]
    const versionResult = onChainResults[baseIdx + 4]
    const roundIdResult = onChainResults[baseIdx + 5]
    const nonceResult = onChainResults[baseIdx + 6]
    const ownerResult = onChainResults[baseIdx + 7]

    if (
      assetResult.status === 'failure' ||
      roundResult.status === 'failure' ||
      !assetResult.result ||
      !roundResult.result
    ) {
      console.warn(`[fetchOracleStats] Critical onchain fetch failed for ${entry.ticker}`)
      continue
    }

    const assetAddress = assetResult.result as Address
    const roundData = roundResult.result as [bigint, bigint, bigint, bigint, bigint]
    const onChainPriceNum = Number(formatUnits(roundData[1], 8))
    const onChainTimestamp = Number(roundData[2])

    const threshold = Number((thresholdResult.result as bigint) ?? 0n)
    const description = (descriptionResult.result as string) ?? ''
    const version = Number((versionResult.result as bigint) ?? 0n)
    // Prioritize roundId from latestRoundData (roundData[0]) over explicit latestRoundId call
    const latestRoundId = roundData[0] || ((roundIdResult.result as bigint) ?? 0n)
    const nonce = (nonceResult.result as bigint) ?? 0n
    const owner = (ownerResult.result as Address) ?? ('0x' as Address)

    const signers: Address[] = []
    for (let sIdx = 0; sIdx < 5; sIdx++) {
      const signerResult = onChainResults[baseIdx + 8 + sIdx]
      if (signerResult.status === 'success' && signerResult.result) {
        signers.push(signerResult.result as Address)
      }
    }

    const offchain = offchainSettled[i]
    const offChainData = offchain?.status === 'fulfilled' && offchain.value ? offchain.value : null

    const nowSec = Math.floor(Date.now() / 1000)
    const ONE_DAY = 86400
    const onChainAgeSec = nowSec - onChainTimestamp
    const onChainStale = onChainAgeSec >= ONE_DAY
    const offChainTs = offChainData?.timestamp ?? 0
    const offChainAgeSec = offChainTs > 0 ? nowSec - offChainTs : 0
    const offChainStale = offChainTs > 0 && offChainAgeSec >= ONE_DAY
    const eitherStale = onChainStale || offChainStale
    const pricesMatch = offChainData ? Math.abs(onChainPriceNum - offChainData.nav) < 0.0001 : false

    const formatAge = (seconds: number): string => {
      if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
      if (seconds < ONE_DAY) return `${Math.floor(seconds / 3600)}h`
      const days = Math.floor(seconds / ONE_DAY)
      const hours = Math.floor((seconds % ONE_DAY) / 3600)
      return hours > 0 ? `${days}d ${hours}h` : `${days}d`
    }

    let oracleStatus: OracleStatus
    let statusDetail: string

    if (!eitherStale) {
      oracleStatus = 'healthy'
      statusDetail = 'Both on-chain and off-chain data are up to date'
    } else if (onChainStale && offChainStale && pricesMatch) {
      oracleStatus = 'warning'
      statusDetail = `Both sources stale — on-chain: ${formatAge(onChainAgeSec)} ago, off-chain: ${formatAge(offChainAgeSec)} ago. Prices match`
    } else if (onChainStale && offChainStale && !pricesMatch) {
      oracleStatus = 'stale'
      statusDetail = `Both sources stale — on-chain: ${formatAge(onChainAgeSec)} ago, off-chain: ${formatAge(offChainAgeSec)} ago. Prices differ`
    } else if (!onChainStale && offChainStale && pricesMatch) {
      oracleStatus = 'warning'
      statusDetail = `Off-chain stale in ${formatAge(offChainAgeSec)}. Prices match`
    } else if (!onChainStale && offChainStale && !pricesMatch) {
      oracleStatus = 'stale'
      statusDetail = `Off-chain stale in ${formatAge(offChainAgeSec)}. Prices differ`
    } else if (onChainStale && !offChainStale && pricesMatch) {
      oracleStatus = 'warning'
      statusDetail = `On-chain stale in ${formatAge(onChainAgeSec)}. Prices match`
    } else if (onChainStale && !offChainStale) {
      oracleStatus = 'stale'
      statusDetail = `On-chain stale in ${formatAge(onChainAgeSec)}. Newer off-chain price available`
    } else {
      oracleStatus = 'healthy'
      statusDetail = 'Data is current'
    }

    filtered.push({
      ticker: entry.ticker,
      onChainPrice: onChainPriceNum,
      onChainTimestamp,
      offChainPrice: offChainData?.nav ?? 0,
      offChainTimestamp: offChainData?.timestamp ?? 0,
      oracleStatus,
      statusDetail,
      oracleAddress: entry.oracleAddress as Address,
      assetAddress,
      threshold,
      description,
      version,
      latestRoundId,
      nonce,
      owner,
      signers,
      history: [], // Will be filled in second pass
    })
  }

  // Second Pass: Fetch History (Last 10 rounds)
  const historyContracts = filtered.flatMap((stats) => {
    const rounds = []
    const start = stats.latestRoundId > 10n ? stats.latestRoundId - 9n : 1n
    for (let r = start; r <= stats.latestRoundId; r++) {
      rounds.push({
        address: stats.oracleAddress,
        abi: RWA_ORACLE_ABI,
        functionName: 'getRoundData' as const,
        args: [r],
      })
    }
    return rounds
  })

  if (historyContracts.length > 0) {
    const historyResults = await publicClient.multicall({
      contracts: historyContracts,
      allowFailure: true,
    })

    let hIdx = 0
    for (const stats of filtered) {
      const start = stats.latestRoundId > 10n ? stats.latestRoundId - 9n : 1n
      const numRounds = Number(stats.latestRoundId - start + 1n)
      const oracleHistory: { price: number; timestamp: number }[] = []

      for (let j = 0; j < numRounds; j++) {
        const res = historyResults[hIdx++]
        if (res.status === 'success' && res.result) {
          const [, price, timestamp] = res.result as [bigint, bigint, bigint, bigint, bigint]
          if (timestamp > 0n) {
            oracleHistory.push({
              price: Number(formatUnits(price, 8)),
              timestamp: Number(timestamp),
            })
          }
        }
      }
      stats.history = oracleHistory.sort((a, b) => a.timestamp - b.timestamp)
    }
  }

  return filtered
}
