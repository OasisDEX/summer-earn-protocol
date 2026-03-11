import { NextResponse } from 'next/server'
import { unstable_cache } from 'next/cache'
import { createPublicClient, http, parseAbiItem, type Address, formatUnits } from 'viem'
import { selectedNetworkToViemNetwork, CHAIN_RPC_URLS, type NetworkType } from '@/lib/oracle-data'

const APPROX_BLOCK_TIMES: Record<number, number> = {
  8453: 2, // Base
  42161: 0.25, // Arbitrum
  1: 12, // Mainnet
  146: 1, // Sonic
}

const SECONDS_IN_DAY = 86400

const PriceUpdatedEvent = parseAbiItem(
  'event PriceUpdated(int256 price, uint256 timestamp, uint256 latestRoundId)',
)

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const { network, daysBackStart, daysBackEnd, oracles } = body as {
      network: NetworkType
      daysBackStart: number
      daysBackEnd: number
      oracles: { address: Address; ticker: string }[]
    }

    if (!network || !oracles || oracles.length === 0) {
      return NextResponse.json({ events: [] })
    }

    const getCachedEvents = unstable_cache(
      async (
        net: NetworkType,
        start: number,
        end: number,
        orcls: { address: Address; ticker: string }[],
      ) => {
        const chain = selectedNetworkToViemNetwork(net)
        const chainId = chain.id
        const publicClient = createPublicClient({
          chain,
          transport: http(CHAIN_RPC_URLS[chainId]?.[0]),
        })

        const currentBlock = await publicClient.getBlockNumber()
        const blockTimeSec = APPROX_BLOCK_TIMES[chainId] || 2

        const blocksPerDay = Math.floor(SECONDS_IN_DAY / blockTimeSec)

        let toBlock = currentBlock - BigInt(Math.floor(blocksPerDay * start))
        let fromBlock = toBlock - BigInt(Math.floor(blocksPerDay * (end - start)))

        if (fromBlock < 0n) fromBlock = 0n
        if (toBlock < 0n) toBlock = currentBlock

        const oracleAddresses = orcls.map((o) => o.address)
        const oracleToTicker = new Map(orcls.map((o) => [o.address.toLowerCase(), o.ticker]))

        const startTime = Date.now()
        const logs = await publicClient.getLogs({
          address: oracleAddresses,
          event: PriceUpdatedEvent,
          fromBlock,
          toBlock,
        })
        const endTime = Date.now()
        console.log(`[API ${net}] Fetched ${logs.length} logs in ${endTime - startTime}ms`)

        const uniqueBlocks = Array.from(
          new Set(logs.map((l) => l.blockNumber?.toString() || '0')),
        ).filter((b) => b !== '0')

        const blockTimestamps = new Map<string, number>()

        const chunkSize = 10
        for (let i = 0; i < uniqueBlocks.length; i += chunkSize) {
          const chunk = uniqueBlocks.slice(i, i + chunkSize)
          await Promise.all(
            chunk.map(async (b) => {
              const block = await publicClient.getBlock({ blockNumber: BigInt(b) })
              blockTimestamps.set(b, Number(block.timestamp))
            }),
          )
        }

        const evts = logs.map((log) => {
          const blockTimestamp = blockTimestamps.get(log.blockNumber?.toString() || '0') || 0
          const ticker = oracleToTicker.get(log.address.toLowerCase()) || 'UNKNOWN'

          return {
            transactionHash: log.transactionHash as string,
            blockNumber: (log.blockNumber || 0n).toString(),
            timestamp: blockTimestamp,
            ticker,
            oracleAddress: log.address as string,
            price: Number(formatUnits(log.args.price || 0n, 8)),
            priceTimestamp: Number(log.args.timestamp || 0n),
          }
        })

        evts.sort((a, b) => (BigInt(b.blockNumber) > BigInt(a.blockNumber) ? 1 : -1))
        return evts
      },
      [`activity-logs-v1`],
      {
        tags: [`activity-log-${network}`],
        revalidate: 3600, // Revalidate automatically after 1 hour, or manually via tag
      },
    )

    const events = await getCachedEvents(network, daysBackStart, daysBackEnd, oracles)

    return NextResponse.json({ events })
  } catch (error) {
    console.error('API Error fetching activity logs:', error)
    return NextResponse.json({ error: 'Failed to fetch logs' }, { status: 500 })
  }
}
