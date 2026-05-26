'use cache'

import { cacheLife, cacheTag } from 'next/cache'

import { fetchTreasuryBalances, TreasuryData } from '@/services/treasury'

export async function getTreasuryBalancesCached(): Promise<TreasuryData> {
  cacheLife({ stale: 60, revalidate: 300, expire: 1800 })
  cacheTag('treasury')
  return fetchTreasuryBalances()
}
