import { formatUnits, getAddress } from 'viem'

import { CHAIN_CONFIG, ERC20_ABI, SupportedChainId } from '@/config/constants'
import { getPublicClient } from '@/config/rpc'
import { TOKEN_LISTS } from '@/config/tokenLists'

import { fetchPrices } from './prices'

export interface TreasuryHolding {
  token: string
  symbol: string
  chain: string
  balance: string
  formattedBalance: string
  usdValue: number
  value: string
  logoURI?: string
  chainId: number
  address: string
}

export interface AggregatedHolding {
  symbol: string
  name: string
  totalValue: number
  totalBalance: number
  percentage: number
  logoURI?: string
}

export interface TreasuryData {
  totalValue: string
  change24h: string
  holdings: TreasuryHolding[]
  aggregatedHoldings: AggregatedHolding[]
  topHolding?: AggregatedHolding
  error?: string
}

export async function fetchTreasuryBalances(): Promise<TreasuryData> {
  const supportedChains = Object.keys(CHAIN_CONFIG).map(Number) as SupportedChainId[]

  const allHoldings: TreasuryHolding[] = []

  // Collect all symbols to fetch prices for
  const allSymbols = new Set<string>()
  supportedChains.forEach((chainId) => {
    TOKEN_LISTS[chainId].forEach((token) => allSymbols.add(token.symbol))
  })

  // Fetch all prices in one go
  const { prices, error: priceError } = await fetchPrices(Array.from(allSymbols))

  let totalUsdValue = 0

  await Promise.all(
    supportedChains.map(async (chainId) => {
      try {
        const client = getPublicClient(chainId)
        const config = CHAIN_CONFIG[chainId]
        const tokens = TOKEN_LISTS[chainId]

        const timelockAddress = getAddress(config.timelock)

        const multicallResults = await client.multicall({
          contracts: tokens.map((token) => ({
            address: getAddress(token.address),
            abi: ERC20_ABI,
            functionName: 'balanceOf',
            args: [timelockAddress],
          })),
        })

        multicallResults.forEach((result, index) => {
          if (result.status === 'success') {
            const balance = result.result as unknown as bigint
            if (balance > 0n) {
              const token = tokens[index]
              const formattedBalance = formatUnits(balance, token.decimals)
              const price = prices[token.symbol] || 0
              const usdValue = Number(formattedBalance) * price

              totalUsdValue += usdValue

              allHoldings.push({
                token: token.name,
                symbol: token.symbol,
                chain: config.name,
                balance: `${Number(formattedBalance).toLocaleString(undefined, { maximumFractionDigits: 2 })} ${token.symbol}`,
                formattedBalance,
                usdValue,
                value:
                  usdValue > 0
                    ? `$${usdValue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
                    : '—',
                logoURI: token.logoURI,
                chainId,
                address: token.address,
              })
            }
          }
        })
      } catch (error) {
        console.error(`Error fetching treasury for chain ${chainId}:`, error)
      }
    }),
  )

  // Aggregate by symbol
  const aggregationMap = new Map<string, AggregatedHolding>()
  allHoldings.forEach((h) => {
    const existing = aggregationMap.get(h.symbol)
    if (existing) {
      existing.totalValue += h.usdValue
      existing.totalBalance += Number(h.formattedBalance)
    } else {
      aggregationMap.set(h.symbol, {
        symbol: h.symbol,
        name: h.token,
        totalValue: h.usdValue,
        totalBalance: Number(h.formattedBalance),
        percentage: 0,
        logoURI: h.logoURI,
      })
    }
  })

  const aggregatedHoldings = Array.from(aggregationMap.values()).map((h) => ({
    ...h,
    percentage: totalUsdValue > 0 ? (h.totalValue / totalUsdValue) * 100 : 0,
  }))

  aggregatedHoldings.sort((a, b) => b.totalValue - a.totalValue)
  const topHolding = aggregatedHoldings[0]

  // Sort raw holdings by USD value descending
  allHoldings.sort((a, b) => b.usdValue - a.usdValue)

  return {
    totalValue: `$${totalUsdValue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`,
    change24h: '+0.00%',
    holdings: allHoldings,
    aggregatedHoldings,
    topHolding,
    error: priceError,
  }
}
