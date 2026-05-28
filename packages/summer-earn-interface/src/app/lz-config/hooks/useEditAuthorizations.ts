'use client'
import { useMemo } from 'react'
import { useQueries } from '@tanstack/react-query'
import type { Address } from 'viem'
import { useAccount } from 'wagmi'

import { getEndpoint, getOAppAddress } from '../lib/configReader'
import { canConnectedWalletSubmit } from '../lib/editAuth'
import { LZ_ENDPOINT_ABI, OAPP_ABI } from '../lib/lzAbi'
import type { ChainName, OAppKind, PendingEdit } from '../lib/types'
import { makePublicClient } from './usePublicClient'

export interface EditAuthResult {
  canSubmit: boolean
  reason?: string
}

function pairKey(chain: ChainName, oApp: OAppKind): string {
  return `${chain}:${oApp}`
}

export function useEditAuthorizations(edits: PendingEdit[]): EditAuthResult[] {
  const { address } = useAccount()

  const uniquePairs = useMemo(() => {
    const seen = new Map<string, { chain: ChainName; oApp: OAppKind }>()
    for (const e of edits) {
      seen.set(pairKey(e.sourceChain, e.oApp), { chain: e.sourceChain, oApp: e.oApp })
    }
    return Array.from(seen.values())
  }, [edits])

  const queries = useQueries({
    queries: uniquePairs.map(({ chain, oApp }) => ({
      queryKey: ['lz-admin', chain, oApp],
      enabled: true,
      staleTime: 60_000,
      queryFn: async (): Promise<{ owner: Address | null; delegate: Address | null }> => {
        const endpoint = getEndpoint(chain)
        const oAppAddress = getOAppAddress(chain, oApp)
        if (!endpoint || !oAppAddress) throw new Error('not ready')
        const client = makePublicClient(chain)
        if (!client) throw new Error('no client')
        const tryRead = async <T>(fn: () => Promise<T>): Promise<T | null> => {
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
    })),
  })

  // Build a stable, primitive signature of the query results so the memo
  // recomputes when any underlying owner/delegate actually changes. Using
  // `.join('|')` on the raw objects would collapse to `[object Object]` and
  // never invalidate.
  const queriesSignature = queries
    .map((q) => `${q.data?.owner ?? ''}|${q.data?.delegate ?? ''}`)
    .join(',')

  const adminByPair = useMemo(() => {
    const map = new Map<string, { owner: Address | null; delegate: Address | null }>()
    uniquePairs.forEach((p, i) => {
      const d = queries[i]?.data
      if (d) map.set(pairKey(p.chain, p.oApp), d)
    })
    return map
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [uniquePairs, queriesSignature])

  return edits.map((e) => {
    const admin = adminByPair.get(pairKey(e.sourceChain, e.oApp))
    if (!admin) return { canSubmit: false, reason: 'Loading owner/delegate…' }
    const ok = canConnectedWalletSubmit(e, address, admin.owner, admin.delegate)
    if (ok) return { canSubmit: true }
    return {
      canSubmit: false,
      reason:
        e.kind === 'setPeer' || e.kind === 'setDelegate' || e.kind === 'setEnforcedOptions'
          ? 'Owner-only action — connect the OApp owner wallet'
          : 'Delegate-permitted — connect the delegate or owner wallet',
    }
  })
}
