'use client'
import { useQuery } from '@tanstack/react-query'
import type { Address, Hex } from 'viem'

import {
  getEid,
  getEndpoint,
  getOAppAddress,
  getReceiveLib,
  getSendLib,
} from '../lib/configReader'
import { decodeExecutorConfig, decodeUlnConfig } from '../lib/encodeDecode'
import {
  CONFIG_TYPE_EXECUTOR,
  CONFIG_TYPE_ULN,
  LZ_ENDPOINT_ABI,
  OAPP_ABI,
} from '../lib/lzAbi'
import { ChainName, OAppKind, OnChainRouteConfig } from '../lib/types'
import { useLzPublicClient } from './usePublicClient'

const STALE_TIME_MS = 30_000

export function useOnChainRouteState(
  sourceChain: ChainName,
  oApp: OAppKind,
  remoteChain: ChainName,
) {
  const client = useLzPublicClient(sourceChain)
  const endpoint = getEndpoint(sourceChain)
  const oAppAddress = getOAppAddress(sourceChain, oApp)
  const remoteEid = getEid(remoteChain)

  const enabled = !!(client && endpoint && oAppAddress && remoteEid)

  return useQuery<OnChainRouteConfig>({
    queryKey: ['lz-onchain', sourceChain, oApp, remoteChain],
    enabled,
    staleTime: STALE_TIME_MS,
    queryFn: async () => {
      if (!client || !endpoint || !oAppAddress || !remoteEid) {
        throw new Error('not ready')
      }

      // Use the configured libs as a fallback when reading send/receive config —
      // but we resolve the *actual* libraries via getSendLibrary / getReceiveLibrary
      const fallbackSend = getSendLib(sourceChain)
      const fallbackReceive = getReceiveLib(sourceChain)

      const tryRead = async <T,>(fn: () => Promise<T>): Promise<T | null> => {
        try {
          return await fn()
        } catch {
          return null
        }
      }

      const [peer, sendLib, receivePair] = await Promise.all([
        tryRead(
          () =>
            // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
            client.readContract({
              address: oAppAddress,
              abi: OAPP_ABI,
              functionName: 'peers',
              args: [remoteEid],
            }) as Promise<Hex>,
        ),
        tryRead(
          () =>
            // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
            client.readContract({
              address: endpoint,
              abi: LZ_ENDPOINT_ABI,
              functionName: 'getSendLibrary',
              args: [oAppAddress, remoteEid],
            }) as Promise<Address>,
        ),
        tryRead(
          () =>
            // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
            client.readContract({
              address: endpoint,
              abi: LZ_ENDPOINT_ABI,
              functionName: 'getReceiveLibrary',
              args: [oAppAddress, remoteEid],
            }) as Promise<readonly [Address, boolean]>,
        ),
      ])

      const effSendLib = sendLib ?? fallbackSend
      const receiveLib = receivePair?.[0] ?? fallbackReceive

      const [sendUlnRaw, executorRaw, recvUlnRaw] = await Promise.all([
        effSendLib
          ? tryRead(
              () =>
                // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
                client.readContract({
                  address: endpoint,
                  abi: LZ_ENDPOINT_ABI,
                  functionName: 'getConfig',
                  args: [oAppAddress, effSendLib as Address, remoteEid, CONFIG_TYPE_ULN],
                }) as Promise<Hex>,
            )
          : Promise.resolve(null),
        effSendLib
          ? tryRead(
              () =>
                // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
                client.readContract({
                  address: endpoint,
                  abi: LZ_ENDPOINT_ABI,
                  functionName: 'getConfig',
                  args: [oAppAddress, effSendLib as Address, remoteEid, CONFIG_TYPE_EXECUTOR],
                }) as Promise<Hex>,
            )
          : Promise.resolve(null),
        receiveLib
          ? tryRead(
              () =>
                // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
                client.readContract({
                  address: endpoint,
                  abi: LZ_ENDPOINT_ABI,
                  functionName: 'getConfig',
                  args: [oAppAddress, receiveLib as Address, remoteEid, CONFIG_TYPE_ULN],
                }) as Promise<Hex>,
            )
          : Promise.resolve(null),
      ])

      return {
        peerBytes32: peer ?? null,
        sendLib: (sendLib ?? null) as Address | null,
        receiveLib: (receivePair?.[0] ?? null) as Address | null,
        sendUln: decodeUlnConfig(sendUlnRaw),
        receiveUln: decodeUlnConfig(recvUlnRaw),
        executor: decodeExecutorConfig(executorRaw),
      }
    },
  })
}
