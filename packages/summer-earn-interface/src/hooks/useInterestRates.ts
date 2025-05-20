import { useQuery } from '@tanstack/react-query'
import { CHAIN_SUBGRAPH_URLS } from '../config/chains'
import { ChainId } from '../types'
import { DailyInterestRate, HourlyInterestRate, InterestRate, Product } from '../types/subgraph'

const fetchProducts = async (chainId: ChainId): Promise<Product[]> => {
  const response = await fetch(CHAIN_SUBGRAPH_URLS[chainId], {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: `
        query {
          products {
            id
            name
            protocol
            token {
              id
              address
              symbol
              decimals
              precision
            }
            network
            pool
          }
        }
      `,
    }),
  })

  const data = await response.json()
  return data.data.products
}

const fetchInterestRates = async (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
): Promise<InterestRate[]> => {
  const response = await fetch(CHAIN_SUBGRAPH_URLS[chainId], {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: `
        query($productId: String!, $fromTimestamp: BigInt!) {
          interestRates(
            where: {
              productId: $productId,
              timestamp_gte: $fromTimestamp
            }
            orderBy: timestamp
            orderDirection: asc
            first:1000
          ) {
            id
            type
            rate
            timestamp
            protocol
            token {
              id
              symbol
              decimals
            }
            product {
              id
              name
              protocol
            }
          }
        }
      `,
      variables: {
        productId,
        fromTimestamp: fromTimestamp.toString(),
      },
    }),
  })

  const data = await response.json()
  console.log(data)
  return data.data.interestRates
}

const fetchDailyInterestRates = async (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
): Promise<DailyInterestRate[]> => {
  const response = await fetch(CHAIN_SUBGRAPH_URLS[chainId], {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: `
        query($productId: String!, $fromTimestamp: BigInt!) {
          dailyInterestRates(
            where: {
              productId: $productId,
              date_gte: $fromTimestamp
            }
            orderBy: date
            orderDirection: asc
          ) {
            id
            date
            sumRates
            updateCount
            averageRate
            protocol
            token
            productId
            product {
              id
              name
              protocol
              token {
                id
                symbol
                decimals
              }
            }
            interestRates {
              id
              type
              rate
              timestamp
            }
          }
        }
      `,
      variables: {
        productId,
        fromTimestamp: fromTimestamp.toString(),
      },
    }),
  })

  const data = await response.json()
  return data.data.dailyInterestRates
}

const fetchHourlyInterestRates = async (
  chainId: ChainId,
  productId: string,
  fromTimestamp: number,
): Promise<HourlyInterestRate[]> => {
  const response = await fetch(CHAIN_SUBGRAPH_URLS[chainId], {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      query: `
        query($productId: String!, $fromTimestamp: BigInt!) {
          hourlyInterestRates(
            where: {
              productId: $productId,
              date_gte: $fromTimestamp
            }
            orderBy: date
            orderDirection: asc
          ) {
            id
            date
            sumRates
            updateCount
            averageRate
            protocol
            token
            productId
            product {
              id
              name
              protocol
              token {
                id
                symbol
                decimals
              }
            }
            interestRates {
              id
              type
              rate
              timestamp
            }
          }
        }
      `,
      variables: {
        productId,
        fromTimestamp: fromTimestamp.toString(),
      },
    }),
  })

  const data = await response.json()
  return data.data.hourlyInterestRates
}

export const useProducts = (chainId: ChainId) => {
  return useQuery({
    queryKey: ['products', chainId],
    queryFn: () => fetchProducts(chainId),
  })
}

export const useInterestRates = (chainId: ChainId, productId: string, fromTimestamp: number) => {
  return useQuery({
    queryKey: ['interestRates', chainId, productId, fromTimestamp],
    queryFn: () => fetchInterestRates(chainId, productId, fromTimestamp),
    enabled: !!productId,
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
  })
}
