'use client'

import { useMemo } from 'react'
import { useReadContracts } from 'wagmi'
import { ERC20_ABI, SupportedChainId, CHAIN_CONFIG } from '@/config/constants'
import { TOKEN_LISTS } from '@/config/tokenLists'
import { formatUnits } from 'viem'

export interface TreasuryBalance {
  address: string
  symbol: string
  name: string
  decimals: number
  balance: string
  formattedBalance: string
  logoURI?: string
  chainId: number
}

export function useTreasuryBalances() {
  const supportedChains = Object.keys(CHAIN_CONFIG).map(Number) as SupportedChainId[]

  // Create contract calls for each chain
  const mainnetResults = useReadContracts({
    contracts: TOKEN_LISTS[1].flatMap((token) => [
      {
        address: token.address as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [CHAIN_CONFIG[1].timelock as `0x${string}`],
        chainId: 1,
      },
    ]),
    query: {
      enabled: true,
      retry: 1,
    },
  })

  const baseResults = useReadContracts({
    contracts: TOKEN_LISTS[8453].flatMap((token) => [
      {
        address: token.address as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [CHAIN_CONFIG[8453].timelock as `0x${string}`],
        chainId: 8453,
      },
    ]),
    query: {
      enabled: true,
      retry: 1,
    },
  })

  const arbitrumResults = useReadContracts({
    contracts: TOKEN_LISTS[42161].flatMap((token) => [
      {
        address: token.address as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [CHAIN_CONFIG[42161].timelock as `0x${string}`],
        chainId: 42161,
      },
    ]),
    query: {
      enabled: true,
      retry: 1,
    },
  })

  const sonicResults = useReadContracts({
    contracts: TOKEN_LISTS[146].flatMap((token) => [
      {
        address: token.address as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [CHAIN_CONFIG[146].timelock as `0x${string}`],
        chainId: 146,
      },
    ]),
    query: {
      enabled: true,
      retry: 1,
    },
  })

  // Watch for errors in console
  useMemo(() => {
    if (mainnetResults.error) console.error('Mainnet Treasury Fetch Error:', mainnetResults.error)
    if (baseResults.error) console.error('Base Treasury Fetch Error:', baseResults.error)
    if (arbitrumResults.error)
      console.error('Arbitrum Treasury Fetch Error:', arbitrumResults.error)
    if (sonicResults.error) console.error('Sonic Treasury Fetch Error:', sonicResults.error)
  }, [mainnetResults.error, baseResults.error, arbitrumResults.error, sonicResults.error])

  const isLoading =
    mainnetResults.isLoading ||
    baseResults.isLoading ||
    arbitrumResults.isLoading ||
    sonicResults.isLoading

  const balances = useMemo(() => {
    const allBalances: TreasuryBalance[] = []

    const processResults = (
      chainId: SupportedChainId,
      results: any,
      tokens: (typeof TOKEN_LISTS)[SupportedChainId],
    ) => {
      if (!results.data) return

      results.data.forEach((result: any, index: number) => {
        const balance = result.result as bigint | undefined
        if (balance && balance > 0n) {
          const token = tokens[index]
          if (!token) return
          allBalances.push({
            address: token.address,
            symbol: token.symbol,
            name: token.name,
            decimals: token.decimals,
            balance: balance.toString(),
            formattedBalance: formatUnits(balance, token.decimals),
            logoURI: token.logoURI,
            chainId,
          })
        }
      })
    }

    processResults(1, mainnetResults, TOKEN_LISTS[1])
    processResults(8453, baseResults, TOKEN_LISTS[8453])
    processResults(42161, arbitrumResults, TOKEN_LISTS[42161])
    processResults(146, sonicResults, TOKEN_LISTS[146])

    return allBalances
  }, [mainnetResults, baseResults, arbitrumResults, sonicResults])

  // Only consider it an error if ALL attempts failed and we have no data at all
  const isError =
    !isLoading &&
    balances.length === 0 &&
    (mainnetResults.isError || baseResults.isError || arbitrumResults.isError || sonicResults.isError)

  return {
    balances,
    isLoading,
    isError,
  }
}
