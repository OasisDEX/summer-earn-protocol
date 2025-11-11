import { useQuery } from '@tanstack/react-query'

// Now proxied via Next API routes with server-side caching
import { ChainId } from '../types'
import { DailyInterestRate, HourlyInterestRate, InterestRate, Product } from '../types/subgraph'

const fetchProducts = async (chainId: ChainId): Promise<Product[]> => {
  const response = await fetch(`/api/interest/products?chainId=${encodeURIComponent(chainId)}`, {
    cache: 'no-store',
  })
  const data = await response.json()
  return data as Product[]
}

const fetchInterestRates = async (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
): Promise<InterestRate[]> => {
  const response = await fetch(
    `/api/interest/rates?chainId=${encodeURIComponent(chainId)}&productId=${encodeURIComponent(productId)}&from=${encodeURIComponent(fromTimestamp.toString())}`,
    { cache: 'no-store' },
  )
  const data = await response.json()
  return data as InterestRate[]
}

const fetchDailyInterestRates = async (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
): Promise<DailyInterestRate[]> => {
  const response = await fetch(
    `/api/interest/daily?chainId=${encodeURIComponent(chainId)}&productId=${encodeURIComponent(productId)}&from=${encodeURIComponent(fromTimestamp.toString())}`,
    { cache: 'no-store' },
  )
  const data = await response.json()
  return data as DailyInterestRate[]
}

const fetchHourlyInterestRates = async (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
): Promise<HourlyInterestRate[]> => {
  const response = await fetch(
    `/api/interest/hourly?chainId=${encodeURIComponent(chainId)}&productId=${encodeURIComponent(productId)}&from=${encodeURIComponent(fromTimestamp.toString())}`,
    { cache: 'no-store' },
  )
  const data = await response.json()
  return data as HourlyInterestRate[]
}

export const useProducts = (chainId: ChainId) => {
  return useQuery({
    queryKey: ['products', chainId],
    queryFn: () => fetchProducts(chainId),
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
  })
}

export const useInterestRates = (chainId: ChainId, productId: string, fromTimestamp: number) => {
  return useQuery({
    queryKey: ['interestRates', chainId, productId, fromTimestamp],
    queryFn: () => fetchInterestRates(chainId, productId, fromTimestamp),
    enabled: !!productId,
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
  })
}

export const useDailyInterestRates = (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
) => {
  return useQuery({
    queryKey: ['dailyInterestRates', chainId, productId, fromTimestamp],
    queryFn: () => fetchDailyInterestRates(chainId, productId, fromTimestamp),
    enabled: !!productId,
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
  })
}

export const useHourlyInterestRates = (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
) => {
  return useQuery({
    queryKey: ['hourlyInterestRates', chainId, productId, fromTimestamp],
    queryFn: () => fetchHourlyInterestRates(chainId, productId, fromTimestamp),
    enabled: !!productId,
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
  })
}
