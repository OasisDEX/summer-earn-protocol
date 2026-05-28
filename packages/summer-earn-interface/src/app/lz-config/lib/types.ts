import type { Address, Hex } from 'viem'

import type { ChainId } from '../../../types'

export type ChainName = 'mainnet' | 'arbitrum' | 'base' | 'sonic' | 'hyperliquid'

export type OAppKind = 'SummerToken' | 'SummerGovernorV1' | 'SummerGovernorV2'

export const ALL_CHAINS: readonly ChainName[] = [
  'mainnet',
  'base',
  'arbitrum',
  'sonic',
  'hyperliquid',
]
export const ALL_OAPPS: readonly OAppKind[] = [
  'SummerToken',
  'SummerGovernorV1',
  'SummerGovernorV2',
]

export const CHAIN_NAME_TO_ID: Record<ChainName, ChainId> = {
  mainnet: '1',
  arbitrum: '42161',
  base: '8453',
  sonic: '146',
  hyperliquid: '999',
}

export const CHAIN_ID_TO_NAME: Record<ChainId, ChainName> = {
  '1': 'mainnet',
  '42161': 'arbitrum',
  '8453': 'base',
  '146': 'sonic',
  '999': 'hyperliquid',
}

export interface UlnConfig {
  confirmations: bigint
  requiredDVNCount: number
  optionalDVNCount: number
  optionalDVNThreshold: number
  requiredDVNs: readonly Address[]
  optionalDVNs: readonly Address[]
}

export interface ExecutorConfig {
  maxMessageSize: number
  executorAddress: Address
}

export interface DesiredRouteConfig {
  // From index.json
  eid: number
  peerAddress: Address | null // OApp address on the remote chain (we want our peer to be this)
  sendLib: Address // sendUln302 from source chain
  receiveLib: Address // receiveUln302 from source chain
  executor: ExecutorConfig
  uln: UlnConfig
  dvnsRaw: { lzLabs: string; secondDvn: string; thirdDvn?: string }
}

export interface OnChainRouteConfig {
  peerBytes32: Hex | null // null = call failed / not deployed
  sendLib: Address | null // null = endpoint default
  receiveLib: Address | null
  sendUln: UlnConfig | null // null = no explicit config
  receiveUln: UlnConfig | null
  executor: ExecutorConfig | null
  enforced: EnforcedOptionsState | null
}

export interface OAppAdminState {
  owner: Address | null
  delegate: Address | null
}

export interface EnforcedOptionsState {
  send: Hex | null // null = read failed; '0x' = explicitly empty
  sendAndCall: Hex | null
}

export interface DvnInfo {
  address: Address
  canonicalName: string
  deprecated: boolean
  lzReadCompatible?: boolean
}

export type DvnSeverity = 'info' | 'warn' | 'error'

export interface Recommendation {
  id: string
  severity: DvnSeverity
  message: string
}

export interface RouteState {
  sourceChain: ChainName
  remoteChain: ChainName
  oApp: OAppKind
  oAppAddress: Address
  desired: DesiredRouteConfig | null
  onChain: OnChainRouteConfig | null
  isLoading: boolean
  error: Error | null
}

// PendingEdit represents one EVM transaction the user wants to stage
export type PendingEdit =
  | {
      kind: 'setPeer'
      sourceChain: ChainName
      oApp: OAppKind
      oAppAddress: Address
      remoteChain: ChainName
      eid: number
      peerBytes32: Hex
    }
  | {
      kind: 'setSendLibrary'
      sourceChain: ChainName
      oApp: OAppKind
      oAppAddress: Address
      remoteChain: ChainName
      eid: number
      lib: Address
    }
  | {
      kind: 'setReceiveLibrary'
      sourceChain: ChainName
      oApp: OAppKind
      oAppAddress: Address
      remoteChain: ChainName
      eid: number
      lib: Address
      gracePeriod: bigint
    }
  | {
      kind: 'setSendConfig'
      sourceChain: ChainName
      oApp: OAppKind
      oAppAddress: Address
      remoteChain: ChainName
      eid: number
      sendLib: Address
      executor: ExecutorConfig
      uln: UlnConfig
    }
  | {
      kind: 'setReceiveConfig'
      sourceChain: ChainName
      oApp: OAppKind
      oAppAddress: Address
      remoteChain: ChainName
      eid: number
      receiveLib: Address
      uln: UlnConfig
    }
  | {
      kind: 'setDelegate'
      sourceChain: ChainName
      oApp: OAppKind
      oAppAddress: Address
      delegate: Address
    }
  | {
      kind: 'setEnforcedOptions'
      sourceChain: ChainName
      oApp: OAppKind
      oAppAddress: Address
      entries: { eid: number; msgType: number; options: Hex }[]
    }
