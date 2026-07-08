import { createPublicClient } from 'viem'

import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { harborCommandAbi } from '@/abis/HarborCommand'
import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'
import { type Environment, HARBOR_COMMAND_ADDRESSES } from '@/config/environments'

const POOL_ADDRESS_RE = /^0x[a-fA-F0-9]{40}$/

export type ArkStatus = 'active' | 'ready-to-remove' | 'stuck-needs-sweep'

export interface ArkDetails {
  protocol?: string
  pool?: `0x${string}`
  chainId?: number
}

export function getArkStatus(ark: {
  isBufferArk: boolean
  depositCap: bigint
  totalAssets: bigint
}): ArkStatus {
  if (ark.isBufferArk) return 'active'
  if (ark.depositCap === 0n) {
    return ark.totalAssets === 0n ? 'ready-to-remove' : 'stuck-needs-sweep'
  }
  return 'active'
}

export function parseArkDetails(detailsJson: string | undefined): ArkDetails | null {
  if (!detailsJson) return null
  try {
    const parsed = JSON.parse(detailsJson) as Record<string, unknown>
    const pool =
      typeof parsed.pool === 'string' && POOL_ADDRESS_RE.test(parsed.pool)
        ? (parsed.pool as `0x${string}`)
        : undefined
    const protocol = typeof parsed.protocol === 'string' ? parsed.protocol : undefined
    const chainId = typeof parsed.chainId === 'number' ? parsed.chainId : undefined
    return { protocol, pool, chainId }
  } catch {
    return null
  }
}

export class ArksOverviewError extends Error {
  status: number
  constructor(message: string, status = 502) {
    super(message)
    this.status = status
  }
}

const FLEET_READS_PER_CONTRACT = 6

export interface FleetSummary {
  address: `0x${string}`
  name: string
  symbol: string
  asset: `0x${string}`
  totalAssets: string
  withdrawableTotalAssets: string
  depositCap: string
  minimumBufferBalance: string
  maxRebalanceOperations: string
  assetDecimals: number
  assetSymbol: string
  fleetDecimals: number
}

export async function getFleetsForChain(
  chainId: string,
  environment: Environment,
): Promise<FleetSummary[]> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  const harbor = HARBOR_COMMAND_ADDRESSES[environment][Number(chainId)]
  if (!rpcUrls || !harbor) {
    throw new ArksOverviewError('Unsupported chain or environment', 400)
  }

  const client = createPublicClient({
    transport: createRpcTransport(rpcUrls),
    chain: VIEM_CHAIN_ENTITIES[chainId as keyof typeof VIEM_CHAIN_ENTITIES],
  })

  // @ts-ignore - harborCommandAbi / viem type mismatch (authorizationList)
  const activeFleets = (await client.readContract({
    address: harbor as `0x${string}`,
    abi: harborCommandAbi,
    functionName: 'getActiveFleetCommanders',
  })) as `0x${string}`[]

  const allFleets = [...activeFleets]
  if (chainId === '8453') {
    allFleets.push('0x29f13a877F3d1A14AC0B15B07536D4423b35E198' as `0x${string}`)
  }

  const fleetContracts = allFleets.flatMap((fleetAddress) => [
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'name' as const },
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'symbol' as const },
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'asset' as const },
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'totalAssets' as const },
    {
      address: fleetAddress,
      abi: fleetCommanderAbi,
      functionName: 'withdrawableTotalAssets' as const,
    },
    { address: fleetAddress, abi: fleetCommanderAbi, functionName: 'getConfig' as const },
  ])

  // @ts-expect-error - viem multicall types are overly strict
  const fleetResults = await client.multicall({ contracts: fleetContracts, allowFailure: true })

  const assetAddresses: `0x${string}`[] = []
  const fleetData: Array<{
    address: `0x${string}`
    name: string
    symbol: string
    asset: `0x${string}`
    totalAssets: bigint
    withdrawableTotalAssets: bigint
    config: unknown
  }> = []

  for (let i = 0; i < allFleets.length; i++) {
    const base = i * FLEET_READS_PER_CONTRACT
    const [nameRes, symbolRes, assetRes, totalRes, withdrawableRes, configRes] =
      fleetResults.slice(base, base + FLEET_READS_PER_CONTRACT)

    if (
      nameRes.status === 'failure' ||
      symbolRes.status === 'failure' ||
      assetRes.status === 'failure' ||
      totalRes.status === 'failure' ||
      withdrawableRes.status === 'failure' ||
      configRes.status === 'failure'
    ) {
      throw new ArksOverviewError('Failed to read fleet contract', 502)
    }

    const assetAddress = assetRes.result as `0x${string}`
    assetAddresses.push(assetAddress)
    fleetData.push({
      address: allFleets[i],
      name: nameRes.result as string,
      symbol: symbolRes.result as string,
      asset: assetAddress,
      totalAssets: totalRes.result as bigint,
      withdrawableTotalAssets: withdrawableRes.result as bigint,
      config: configRes.result,
    })
  }

  const assetContracts = assetAddresses.flatMap((assetAddress) => [
    { address: assetAddress, abi: erc20Abi, functionName: 'decimals' as const },
    { address: assetAddress, abi: erc20Abi, functionName: 'symbol' as const },
  ])

  // @ts-expect-error - viem multicall types are overly strict
  const assetResults = await client.multicall({ contracts: assetContracts, allowFailure: true })

  if (assetResults.some((r) => r.status === 'failure')) {
    throw new ArksOverviewError('Failed to read asset contract', 502)
  }

  return fleetData.map((fd, i) => {
    const decimalsRes = assetResults[i * 2]
    const symbolRes = assetResults[i * 2 + 1]
    const assetDecimals = Number(decimalsRes.result)
    const assetSymbol = String(symbolRes.result)

    const configData = fd.config as {
      bufferArk: `0x${string}`
      minimumBufferBalance: bigint
      depositCap: bigint
      maxRebalanceOperations: bigint
      stakingRewardsManager: `0x${string}`
    }

    return {
      address: fd.address,
      name: fd.name,
      symbol: fd.symbol,
      asset: fd.asset,
      totalAssets: fd.totalAssets.toString(),
      withdrawableTotalAssets: fd.withdrawableTotalAssets.toString(),
      depositCap: configData.depositCap.toString(),
      minimumBufferBalance: configData.minimumBufferBalance.toString(),
      maxRebalanceOperations: configData.maxRebalanceOperations.toString(),
      assetDecimals,
      assetSymbol,
      fleetDecimals: assetDecimals,
    }
  })
}
