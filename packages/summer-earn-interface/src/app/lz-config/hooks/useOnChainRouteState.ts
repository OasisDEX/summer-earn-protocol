'use client'
import { useQuery } from '@tanstack/react-query'
import type { Address, Hex } from 'viem'

import { getEid, getEndpoint, getOAppAddress } from '../lib/configReader'
import { decodeExecutorConfig, decodeUlnConfig } from '../lib/encodeDecode'
import { CONFIG_TYPE_EXECUTOR, CONFIG_TYPE_ULN, LZ_ENDPOINT_ABI, OAPP_ABI } from '../lib/lzAbi'
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

      // Resolve the *actual* libraries via getSendLibrary / getReceiveLibrary.
      // If either read reverts (returns null below) we deliberately skip the
      // ULN/Executor reads against that lib — substituting a static fallback
      // would fabricate drift when the OApp has overridden its libs.

      const tryRead = async <T>(fn: () => Promise<T>): Promise<T | null> => {
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

      const effSendLib: Address | null = sendLib ?? null
      const receiveLib: Address | null = receivePair?.[0] ?? null

      const [sendUlnRaw, executorRaw, recvUlnRaw, enfSendRaw, enfSendAndCallRaw] =
        await Promise.all([
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
          tryRead(
            () =>
              // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
              client.readContract({
                address: oAppAddress,
                abi: OAPP_ABI,
                functionName: 'enforcedOptions',
                args: [remoteEid, 1],
              }) as Promise<Hex>,
          ),
          tryRead(
            () =>
              // @ts-ignore - viem readContract / abi-as-const authorizationList mismatch
              client.readContract({
                address: oAppAddress,
                abi: OAPP_ABI,
                functionName: 'enforcedOptions',
                args: [remoteEid, 2],
              }) as Promise<Hex>,
          ),
        ])

      return {
        peerBytes32: peer ?? null,
        sendLib: (sendLib ?? null) as Address | null,
        receiveLib: (receivePair?.[0] ?? null) as Address | null,
        sendUln: decodeUlnConfig(sendUlnRaw),
        receiveUln: decodeUlnConfig(recvUlnRaw),
        executor: decodeExecutorConfig(executorRaw),
        enforced: {
          send: enfSendRaw ?? null,
          sendAndCall: enfSendAndCallRaw ?? null,
        },
      }
    },
  })
}
