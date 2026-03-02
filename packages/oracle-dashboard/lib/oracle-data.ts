import { createPublicClient, http, type Address, formatUnits, Transport, fallback } from 'viem'
import { arbitrum, base, hyperliquid, mainnet, sonic } from 'viem/chains'
import { RWA_ORACLE_ABI, ORACLE_REGISTRY_ABI } from './constants'
import { DeploymentFileSchema } from './schemas'
import { getOffchainFetcher } from './fetchers'
import deploymentsJson from './deployments.json'
import { CHAIN_RPC_URLS } from '@/config/chains'

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

  // Multicall: oracleToAsset + latestRoundData for each oracle (allowFailure: true)
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
  for (let i = 0; i < oracles.length; i++) {
    const entry = oracles[i]
    const assetResult = onChainResults[2 * i]
    const roundResult = onChainResults[2 * i + 1]

    if (
      assetResult.status === 'failure' ||
      roundResult.status === 'failure' ||
      !assetResult.result ||
      !roundResult.result
    ) {
      console.warn(`[fetchOracleStats] Onchain fetch failed for ${entry.ticker}`)
      continue
    }

    const assetAddress = assetResult.result as Address
    const roundData = roundResult.result as [bigint, bigint, bigint, bigint, bigint]
    const onChainPriceNum = Number(formatUnits(roundData[1], 8))
    const onChainTimestamp = Number(roundData[2])

    const offchain = offchainSettled[i]
    const offChainData =
      offchain?.status === 'fulfilled' && offchain.value ? offchain.value : null

    const nowSec = Math.floor(Date.now() / 1000)
    const ONE_DAY = 86400
    const onChainAgeSec = nowSec - onChainTimestamp
    const onChainStale = onChainAgeSec >= ONE_DAY
    const offChainTs = offChainData?.timestamp ?? 0
    const offChainAgeSec = offChainTs > 0 ? nowSec - offChainTs : 0
    const offChainStale = offChainTs > 0 && offChainAgeSec >= ONE_DAY
    const eitherStale = onChainStale || offChainStale
    const pricesMatch = offChainData
      ? Math.abs(onChainPriceNum - offChainData.nav) < 0.0001
      : false

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
      // Both sources are fresh
      oracleStatus = 'healthy'
      statusDetail = 'Both on-chain and off-chain data are up to date'
    } else if (onChainStale && offChainStale && pricesMatch) {
      // Both stale but prices match
      oracleStatus = 'warning'
      statusDetail = `Both sources stale — on-chain: ${formatAge(onChainAgeSec)} ago, off-chain: ${formatAge(offChainAgeSec)} ago. Prices match, verify oracle is running`
    } else if (onChainStale && offChainStale && !pricesMatch) {
      // Both stale and prices differ
      oracleStatus = 'stale'
      statusDetail = `Both sources stale — on-chain: ${formatAge(onChainAgeSec)} ago, off-chain: ${formatAge(offChainAgeSec)} ago. Prices differ, update needed`
    } else if (!onChainStale && offChainStale && pricesMatch) {
      // On-chain fresh, off-chain stale, prices match
      oracleStatus = 'warning'
      statusDetail = `No off-chain data update in ${formatAge(offChainAgeSec)}. Prices match, check off-chain source`
    } else if (!onChainStale && offChainStale && !pricesMatch) {
      // On-chain fresh, off-chain stale, prices differ
      oracleStatus = 'stale'
      statusDetail = `No off-chain data update in ${formatAge(offChainAgeSec)}. Prices differ, off-chain source may be down`
    } else if (onChainStale && !offChainStale && pricesMatch) {
      // On-chain stale, off-chain fresh, prices match
      oracleStatus = 'warning'
      statusDetail = `On-chain not updated in ${formatAge(onChainAgeSec)}. Prices match, verify oracle node is running`
    } else if (onChainStale && !offChainStale) {
      // On-chain stale, off-chain fresh, prices differ
      oracleStatus = 'stale'
      statusDetail = `On-chain not updated in ${formatAge(onChainAgeSec)}. Off-chain has newer price, update needed`
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
    })
  }

  return filtered
}
