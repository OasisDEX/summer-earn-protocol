import { formatUnits, getAddress } from 'viem'

import { CHAIN_CONFIG, ERC20_ABI, SupportedChainId, TokenInfo } from '@/config/constants'
import { getPublicClient } from '@/config/rpc'
import { TOKEN_LISTS } from '@/config/tokenLists'
import { TREASURY_WALLETS, TreasuryWallet } from '@/config/treasuryWallets'

import { getPrices } from './prices'
import { getWrappedSlipstreamTokenAmounts } from './slipstream'

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
  walletKey: string
  walletLabel: string
}

export interface AggregatedHolding {
  symbol: string
  name: string
  totalValue: number
  totalBalance: number
  percentage: number
  logoURI?: string
}

export interface WalletSection {
  key: string
  label: string
  externalUrl?: string
  totalValue: number
  value: string
  holdings: TreasuryHolding[]
}

export interface TreasuryData {
  totalValue: string
  holdings: TreasuryHolding[]
  aggregatedHoldings: AggregatedHolding[]
  wallets: WalletSection[]
  topHolding?: AggregatedHolding
  error?: string
}

type PublicClient = ReturnType<typeof getPublicClient>
type PriceMap = Record<string, number>

function formatUsd(value: number): string {
  return `$${value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

// Read ERC20 balances for every token in the chain's token list against `owner`.
async function scanErc20(
  client: PublicClient,
  chainId: SupportedChainId,
  owner: string,
  prices: PriceMap,
  wallet: TreasuryWallet,
): Promise<TreasuryHolding[]> {
  const config = CHAIN_CONFIG[chainId]
  const tokens = TOKEN_LISTS[chainId]
  const ownerAddress = getAddress(owner)

  const multicallResults = await client.multicall({
    contracts: tokens.map((token) => ({
      address: getAddress(token.address),
      abi: ERC20_ABI,
      functionName: 'balanceOf',
      args: [ownerAddress],
    })),
  })

  const holdings: TreasuryHolding[] = []
  multicallResults.forEach((result, index) => {
    if (result.status !== 'success') return
    const balance = result.result as unknown as bigint
    if (balance <= 0n) return

    const token = tokens[index]
    const formattedBalance = formatUnits(balance, token.decimals)
    const price = prices[token.symbol] || 0
    const usdValue = Number(formattedBalance) * price

    holdings.push({
      token: token.name,
      symbol: token.symbol,
      chain: config.name,
      balance: `${Number(formattedBalance).toLocaleString(undefined, { maximumFractionDigits: 2 })} ${token.symbol}`,
      formattedBalance,
      usdValue,
      value: usdValue > 0 ? formatUsd(usdValue) : '—',
      logoURI: token.logoURI,
      chainId,
      address: token.address,
      walletKey: wallet.key,
      walletLabel: wallet.label,
    })
  })

  return holdings
}

// Value the wallet's Aerodrome Slipstream LP positions (token amounts priced like
// the ERC20 holdings). Tokens not in the chain's token list are skipped.
async function scanSlipstreamPositions(
  chainId: SupportedChainId,
  owner: string,
  prices: PriceMap,
  wallet: TreasuryWallet,
): Promise<TreasuryHolding[]> {
  const sources = (wallet.slipstreamPositions ?? []).filter((s) => s.chainId === chainId)
  if (sources.length === 0) return []

  const tokenByAddress = new Map<string, TokenInfo>(
    TOKEN_LISTS[chainId].map((t) => [t.address.toLowerCase(), t]),
  )
  const config = CHAIN_CONFIG[chainId]
  const holdings: TreasuryHolding[] = []

  for (const source of sources) {
    const amounts = await getWrappedSlipstreamTokenAmounts(chainId, owner, source)
    for (const { tokenAddress, amount } of amounts) {
      const token = tokenByAddress.get(tokenAddress.toLowerCase())
      if (!token) continue

      const formattedBalance = formatUnits(amount, token.decimals)
      const price = prices[token.symbol] || 0
      const usdValue = Number(formattedBalance) * price

      holdings.push({
        token: `${token.name} (Aerodrome LP)`,
        symbol: token.symbol,
        chain: config.name,
        balance: `${Number(formattedBalance).toLocaleString(undefined, { maximumFractionDigits: 2 })} ${token.symbol}`,
        formattedBalance,
        usdValue,
        value: usdValue > 0 ? formatUsd(usdValue) : '—',
        logoURI: token.logoURI,
        chainId,
        address: token.address,
        walletKey: wallet.key,
        walletLabel: wallet.label,
      })
    }
  }

  return holdings
}

export async function fetchTreasuryBalances(): Promise<TreasuryData> {
  const supportedChains = Object.keys(CHAIN_CONFIG).map(Number) as SupportedChainId[]

  // Main treasury is the per-chain timelock; the named wallets follow it.
  const mainTreasury: TreasuryWallet = {
    key: 'main-treasury',
    label: 'Main Treasury',
    addresses: Object.fromEntries(
      supportedChains.map((chainId) => [chainId, CHAIN_CONFIG[chainId].timelock]),
    ) as Partial<Record<SupportedChainId, string>>,
  }
  const wallets: TreasuryWallet[] = [mainTreasury, ...TREASURY_WALLETS]

  // Collect all symbols to fetch prices for in one call.
  const allSymbols = new Set<string>()
  supportedChains.forEach((chainId) => {
    TOKEN_LISTS[chainId].forEach((token) => allSymbols.add(token.symbol))
  })
  const { prices, error: priceError } = await getPrices(Array.from(allSymbols))

  // Fan out across every (wallet, chain) pair.
  const results = await Promise.all(
    wallets.flatMap((wallet) =>
      (Object.entries(wallet.addresses) as [string, string][]).map(
        async ([chainIdStr, address]) => {
          const chainId = Number(chainIdStr) as SupportedChainId
          try {
            const client = getPublicClient(chainId)
            const [erc20Holdings, slipstreamHoldings] = await Promise.all([
              scanErc20(client, chainId, address, prices, wallet),
              scanSlipstreamPositions(chainId, address, prices, wallet),
            ])
            return { key: wallet.key, holdings: [...erc20Holdings, ...slipstreamHoldings] }
          } catch (error) {
            console.error(`Error fetching ${wallet.key} on chain ${chainId}:`, error)
            return { key: wallet.key, holdings: [] as TreasuryHolding[] }
          }
        },
      ),
    ),
  )

  // Group holdings back into per-wallet sections, preserving wallet order.
  const sections: WalletSection[] = wallets
    .map((wallet) => {
      const holdings = results
        .filter((r) => r.key === wallet.key)
        .flatMap((r) => r.holdings)
        .sort((a, b) => b.usdValue - a.usdValue)
      const totalValue = holdings.reduce((sum, h) => sum + h.usdValue, 0)
      return {
        key: wallet.key,
        label: wallet.label,
        externalUrl: wallet.externalUrl,
        totalValue,
        value: formatUsd(totalValue),
        holdings,
      }
    })
    .filter((section) => section.holdings.length > 0)

  const allHoldings = sections.flatMap((s) => s.holdings)
  const totalUsdValue = sections.reduce((sum, s) => sum + s.totalValue, 0)

  // Aggregate by symbol across every wallet for the "Top Holdings" cards.
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

  // Sort raw holdings by USD value descending (kept for compatibility).
  allHoldings.sort((a, b) => b.usdValue - a.usdValue)

  return {
    totalValue: formatUsd(totalUsdValue),
    holdings: allHoldings,
    aggregatedHoldings,
    wallets: sections,
    topHolding,
    error: priceError,
  }
}
