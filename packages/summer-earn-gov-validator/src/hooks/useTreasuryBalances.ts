'use client'

import { useMemo } from 'react'
import { formatUnits, getAddress } from 'viem'
import { useReadContracts } from 'wagmi'

import { CHAIN_CONFIG, ERC20_ABI, SupportedChainId } from '@/config/constants'
import { TOKEN_LISTS } from '@/config/tokenLists'

export interface TreasuryBalance {
  address: string
  symbol: string
  name: string
  decimals: number
  balance: string
  formattedBalance: string
  logoURI?: string | undefined
  chainId: number
}

export function useTreasuryBalances() {
  const supportedChains = Object.keys(CHAIN_CONFIG).map(Number) as SupportedChainId[]

  // Flatten tokens across all supported chains
  const allTokens = useMemo(() => {
    return supportedChains.flatMap((chainId) =>
      TOKEN_LISTS[chainId].map((token) => ({
        ...token,
        chainId,
      })),
    )
  }, [supportedChains])

  // Create contract calls for each token/chain
  const contracts = useMemo(() => {
    return allTokens.map((token) => ({
      address: getAddress(token.address),
      abi: ERC20_ABI,
      functionName: 'balanceOf',
      args: [getAddress(CHAIN_CONFIG[token.chainId as SupportedChainId].timelock)],
      chainId: token.chainId,
    }))
  }, [allTokens])

  const { data, isLoading, isError, refetch } = useReadContracts({
    contracts,
    query: {
      enabled: true,
      retry: 1,
    },
  })

  // Watch for errors in console
  useMemo(() => {
    if (isError) {
      console.error('Treasury Fetch Error: One or more RPC reads failed.')
    }
  }, [isError])

  const balances = useMemo(() => {
    if (!data) return []

    return data
      .map((result, index) => {
        const balance = result.result as bigint | undefined
        if (balance && balance > 0n) {
          const token = allTokens[index]
          if (!token) return null
          const b: TreasuryBalance = {
            address: token.address,
            symbol: token.symbol,
            name: token.name,
            decimals: token.decimals,
            balance: balance.toString(),
            formattedBalance: formatUnits(balance, token.decimals),
            logoURI: token.logoURI ?? undefined,
            chainId: token.chainId as number,
          }
          return b
        }
        return null
      })
      .filter((b): b is TreasuryBalance => !!b)
  }, [data, allTokens])

  return {
    balances,
    isLoading,
    isError: isError && balances.length === 0,
    refetch,
  }
}
