import { Address, decodeAbiParameters, encodeAbiParameters, Hex } from 'viem'

import { ExecutorConfig, UlnConfig } from './types'

const ULN_PARAMS = [
  {
    type: 'tuple',
    components: [
      { name: 'confirmations', type: 'uint64' },
      { name: 'requiredDVNCount', type: 'uint8' },
      { name: 'optionalDVNCount', type: 'uint8' },
      { name: 'optionalDVNThreshold', type: 'uint8' },
      { name: 'requiredDVNs', type: 'address[]' },
      { name: 'optionalDVNs', type: 'address[]' },
    ],
  },
] as const

const EXECUTOR_PARAMS = [
  {
    type: 'tuple',
    components: [
      { name: 'maxMessageSize', type: 'uint32' },
      { name: 'executorAddress', type: 'address' },
    ],
  },
] as const

export function decodeUlnConfig(raw: Hex | undefined | null): UlnConfig | null {
  if (!raw || raw === '0x' || raw.length <= 2) return null
  try {
    const [decoded] = decodeAbiParameters(ULN_PARAMS, raw)
    return {
      confirmations: decoded.confirmations,
      requiredDVNCount: decoded.requiredDVNCount,
      optionalDVNCount: decoded.optionalDVNCount,
      optionalDVNThreshold: decoded.optionalDVNThreshold,
      requiredDVNs: decoded.requiredDVNs as readonly Address[],
      optionalDVNs: decoded.optionalDVNs as readonly Address[],
    }
  } catch {
    return null
  }
}

export function encodeUlnConfig(uln: UlnConfig): Hex {
  return encodeAbiParameters(ULN_PARAMS, [uln])
}

export function decodeExecutorConfig(raw: Hex | undefined | null): ExecutorConfig | null {
  if (!raw || raw === '0x' || raw.length <= 2) return null
  try {
    const [decoded] = decodeAbiParameters(EXECUTOR_PARAMS, raw)
    return {
      maxMessageSize: decoded.maxMessageSize,
      executorAddress: decoded.executorAddress as Address,
    }
  } catch {
    return null
  }
}

export function encodeExecutorConfig(cfg: ExecutorConfig): Hex {
  return encodeAbiParameters(EXECUTOR_PARAMS, [cfg])
}

export function addressToBytes32(addr: Address): Hex {
  // Lowercase, strip 0x, left-pad to 64 hex chars
  const hex = addr.replace(/^0x/, '').toLowerCase().padStart(64, '0')
  return `0x${hex}` as Hex
}

export function bytes32ToAddress(b32: Hex): Address | null {
  if (!b32 || b32 === '0x' || b32.length !== 66) return null
  // Last 40 chars = 20 bytes
  const addr = b32.slice(-40)
  if (/^0+$/.test(addr)) return null
  return `0x${addr}` as Address
}
