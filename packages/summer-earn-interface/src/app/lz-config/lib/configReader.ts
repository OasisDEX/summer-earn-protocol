import type { Address } from 'viem'

import configJson from '../../../config/deployment/index.json'
import type { ChainName, DesiredRouteConfig, ExecutorConfig, OAppKind, UlnConfig } from './types'

type ConfigChainData = {
  common?: Record<string, Record<string, unknown>>
  deployedContracts?: Record<string, Record<string, { address?: string }>>
  bridge?: Record<string, unknown>
  tokens?: Record<string, unknown>
  protocolSpecific?: Record<string, unknown>
}

const configData = configJson as unknown as Record<string, ConfigChainData>

const DEFAULT_CONFIRMATIONS = 15n
const DEFAULT_MAX_MESSAGE_SIZE = 10000

export function getConfirmations(chain: ChainName): bigint {
  const v = configData[chain]?.common?.layerZero?.confirmations
  return v != null ? BigInt(v as string | number | bigint) : DEFAULT_CONFIRMATIONS
}

export function getEid(chain: ChainName): number {
  const v = configData[chain]?.common?.layerZero?.eID
  return v ? Number(v) : 0
}

export function getEndpoint(chain: ChainName): Address | null {
  return (configData[chain]?.common?.layerZero?.lzEndpoint as Address) ?? null
}

export function getSendLib(chain: ChainName): Address | null {
  return (configData[chain]?.common?.layerZero?.sendUln302 as Address) ?? null
}

export function getReceiveLib(chain: ChainName): Address | null {
  return (configData[chain]?.common?.layerZero?.receiveUln302 as Address) ?? null
}

export function getExecutor(chain: ChainName): ExecutorConfig | null {
  const addr = configData[chain]?.common?.layerZero?.lzExecutor as Address | undefined
  if (!addr) return null
  return { maxMessageSize: DEFAULT_MAX_MESSAGE_SIZE, executorAddress: addr }
}

export function getOAppAddress(chain: ChainName, kind: OAppKind): Address | null {
  const dc = configData[chain]?.deployedContracts
  switch (kind) {
    case 'SummerToken':
      return (dc?.gov?.summerToken?.address as Address) ?? null
    case 'SummerGovernorV1':
      return (dc?.gov?.summerGovernor?.address as Address) ?? null
    case 'SummerGovernorV2':
      return (dc?.govV2?.summerGovernor?.address as Address) ?? null
  }
}

export function getDesiredUln(
  sourceChain: ChainName,
  remoteChain: ChainName,
  confirmations: bigint,
): UlnConfig | null {
  const lz = configData[sourceChain]?.common?.layerZero as Record<string, unknown> | undefined
  const dvnsObj = lz?.dvns as Record<string, Record<string, Address>> | undefined
  const dvns = dvnsObj?.[remoteChain]
  if (!dvns || !dvns.lzLabs || !dvns.secondDvn) return null

  // Three-tier model:
  //   - 4 DVNs available: LZ "2-of-3 redundant" (X=2 required + N=2 optional threshold=1)
  //   - 3 DVNs available: LZ named "2-of-3" (X=2 required + N=1 optional threshold=1)
  //   - 2 DVNs available: 2-of-2 strict fallback
  const hasFourDvns =
    typeof dvns.thirdDvn === 'string' &&
    dvns.thirdDvn.length > 0 &&
    typeof dvns.horizen === 'string' &&
    dvns.horizen.length > 0
  const hasThirdDvn = typeof dvns.thirdDvn === 'string' && dvns.thirdDvn.length > 0

  if (hasFourDvns) {
    // LZ "2-of-3 redundant": X=2 required + N=2 optional threshold=1.
    // Required: LZ Labs + Nethermind (slots: lzLabs + thirdDvn).
    // Optional: Deutsche Telekom + Horizen (slots: secondDvn + horizen).
    return {
      confirmations,
      requiredDVNCount: 2,
      optionalDVNCount: 2,
      optionalDVNThreshold: 1,
      requiredDVNs: ([dvns.lzLabs, dvns.thirdDvn] as Address[]).sort((a, b) =>
        a.toLowerCase().localeCompare(b.toLowerCase()),
      ) as readonly Address[],
      optionalDVNs: ([dvns.secondDvn, dvns.horizen] as Address[]).sort((a, b) =>
        a.toLowerCase().localeCompare(b.toLowerCase()),
      ) as readonly Address[],
    }
  }
  if (hasThirdDvn) {
    // 3-DVN fallback: LZ Labs required + 1-of-2 optional (secondDvn / thirdDvn).
    // True 2-of-3 with LZ Labs as a fixed attestor — tolerates one optional DVN
    // outage, instead of the strict 3-of-3 we'd get with all DVNs required.
    return {
      confirmations,
      requiredDVNCount: 1,
      optionalDVNCount: 2,
      optionalDVNThreshold: 1,
      requiredDVNs: ([dvns.lzLabs] as Address[]).sort((a, b) =>
        a.toLowerCase().localeCompare(b.toLowerCase()),
      ) as readonly Address[],
      optionalDVNs: ([dvns.secondDvn, dvns.thirdDvn] as Address[]).sort((a, b) =>
        a.toLowerCase().localeCompare(b.toLowerCase()),
      ) as readonly Address[],
    }
  }
  // 2-of-2 strict — last-resort fallback when neither thirdDvn nor horizen is set.
  return {
    confirmations,
    requiredDVNCount: 2,
    optionalDVNCount: 0,
    optionalDVNThreshold: 0,
    requiredDVNs: ([dvns.lzLabs, dvns.secondDvn] as Address[]).sort((a, b) =>
      a.toLowerCase().localeCompare(b.toLowerCase()),
    ) as readonly Address[],
    optionalDVNs: [] as readonly Address[],
  }
}

export function getDesiredRouteConfig(
  sourceChain: ChainName,
  remoteChain: ChainName,
  oApp: OAppKind,
): DesiredRouteConfig | null {
  const eid = getEid(remoteChain)
  const sendLib = getSendLib(sourceChain)
  const receiveLib = getReceiveLib(sourceChain)
  const executor = getExecutor(sourceChain)
  const sendUln = getDesiredUln(sourceChain, remoteChain, getConfirmations(sourceChain))
  const receiveUln = getDesiredUln(sourceChain, remoteChain, getConfirmations(remoteChain))
  const peerAddress = getOAppAddress(remoteChain, oApp)
  const dvnsRaw = configData[sourceChain]?.common?.layerZero?.dvns?.[remoteChain]

  if (!eid || !sendLib || !receiveLib || !executor || !sendUln || !receiveUln || !dvnsRaw)
    return null

  return { eid, peerAddress, sendLib, receiveLib, executor, sendUln, receiveUln, dvnsRaw }
}

export function listRemoteChainsWithDvns(sourceChain: ChainName): ChainName[] {
  const dvns = configData[sourceChain]?.common?.layerZero?.dvns ?? {}
  const knownChains: ChainName[] = ['mainnet', 'arbitrum', 'base', 'sonic', 'hyperliquid']
  return knownChains.filter((c) => c !== sourceChain && dvns[c])
}
