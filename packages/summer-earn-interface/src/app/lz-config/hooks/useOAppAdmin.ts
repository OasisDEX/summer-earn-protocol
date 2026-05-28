'use client'
import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'

import { getEndpoint, getOAppAddress } from '../lib/configReader'
import { LZ_ENDPOINT_ABI, OAPP_ABI } from '../lib/lzAbi'
import type { ChainName, OAppAdminState, OAppKind } from '../lib/types'
import { useLzPublicClient } from './usePublicClient'

const STALE_TIME_MS = 60_000

export function useOAppAdmin(sourceChain: ChainName, oApp: OAppKind) {
  const client = useLzPublicClient(sourceChain)
  const endpoint = getEndpoint(sourceChain)
  const oAppAddress = getOAppAddress(sourceChain, oApp)
  const enabled = !!(client && endpoint && oAppAddress)

  return useQuery<OAppAdminState>({
    queryKey: ['lz-admin', sourceChain, oApp],
    enabled,
    staleTime: STALE_TIME_MS,
    queryFn: async () => {
      if (!client || !endpoint || !oAppAddress) throw new Error('not ready')
      const tryRead = async <T,>(fn: () => Promise<T>): Promise<T | null> => {
        try {
          return await fn()
        } catch {
          return null
        }
      }
      const [owner, delegate] = await Promise.all([
        tryRead(
          () =>
            // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
            client.readContract({
              address: oAppAddress,
              abi: OAPP_ABI,
              functionName: 'owner',
              args: [],
            }) as Promise<Address>,
        ),
        tryRead(
          () =>
            // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
            client.readContract({
              address: endpoint,
              abi: LZ_ENDPOINT_ABI,
              functionName: 'delegates',
              args: [oAppAddress],
            }) as Promise<Address>,
        ),
      ])
      return { owner: owner ?? null, delegate: delegate ?? null }
    },
  })
}
