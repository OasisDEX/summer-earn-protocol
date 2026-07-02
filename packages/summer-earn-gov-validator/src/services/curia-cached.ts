'use cache'

import { cacheLife, cacheTag } from 'next/cache'

import { CuriaDelegateData, getCuriaDelegates } from './curia'

// In-process layer over the DynamoDB-cached Curia fetch (which holds a 1-day TTL);
// this only saves the DynamoDB round-trip between renders on the same instance.
export async function getCuriaDelegatesCached(): Promise<Record<string, CuriaDelegateData>> {
  cacheLife('hours')
  cacheTag('curia', 'delegates')
  return getCuriaDelegates()
}
