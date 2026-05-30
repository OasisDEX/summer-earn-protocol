// Reads TipJar / DAO TipJar / HarborCommand addresses per chain from the synced
// deployment config (src/config/deployment/index.json). This file holds the
// production deployment, so the TipJar page always operates on production
// addresses regardless of the header environment toggle.
import configJson from '../../../config/deployment/index.json'
import type { ChainId } from '../../../types'

const ZERO = '0x0000000000000000000000000000000000000000'

// Chains where the TipJar UI is available (a non-zero tipJar is deployed and the
// chain is supported by the frontend). Monad is excluded — not a frontend chain.
export const TIPJAR_CHAINS: ChainId[] = ['1', '42161', '8453', '146', '999']

export interface TipJarInstance {
  /** Display label, e.g. 'TipJar' or 'DAO TipJar'. */
  label: string
  address: `0x${string}`
}

const CHAIN_ID_TO_NAME: Record<ChainId, string> = {
  '1': 'mainnet',
  '42161': 'arbitrum',
  '8453': 'base',
  '146': 'sonic',
  '999': 'hyperliquid',
}

const configData: any = configJson

function getCore(chainId: ChainId): any | null {
  const chainName = CHAIN_ID_TO_NAME[chainId]
  return configData?.[chainName]?.deployedContracts?.core ?? null
}

function isRealAddress(addr: unknown): addr is `0x${string}` {
  return typeof addr === 'string' && addr.length === 42 && addr.toLowerCase() !== ZERO
}

/**
 * Returns the TipJar instances deployed on a chain. `core.tipJar` is always
 * included when present; `core.daoTipJar` is added when it exists (mainnet only).
 */
export function getTipJarInstances(chainId: ChainId): TipJarInstance[] {
  const core = getCore(chainId)
  if (!core) return []

  const instances: TipJarInstance[] = []
  if (isRealAddress(core.tipJar?.address)) {
    instances.push({ label: 'TipJar', address: core.tipJar.address })
  }
  if (isRealAddress(core.daoTipJar?.address)) {
    instances.push({ label: 'DAO TipJar', address: core.daoTipJar.address })
  }
  return instances
}

/** Returns the HarborCommand address for a chain (source of active fleet commanders). */
export function getHarborCommand(chainId: ChainId): `0x${string}` | null {
  const core = getCore(chainId)
  const addr = core?.harborCommand?.address
  return isRealAddress(addr) ? addr : null
}
