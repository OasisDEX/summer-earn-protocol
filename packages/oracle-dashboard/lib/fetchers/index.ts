import type { OracleType, OracleSubtype } from '../schemas'
import type { OracleData } from './wisdomtree-variable-nav'
import { fetchOracleData as fetchWisdomTreeVariableNav } from './wisdomtree-variable-nav'

export type OffchainFetcher = (identifier: string) => Promise<OracleData>

/**
 * Returns the offchain fetcher for the given oracle type and subtype.
 * Returns null if no fetcher is implemented for the combination.
 */
export function getOffchainFetcher(
  type: OracleType,
  subtype: OracleSubtype,
): OffchainFetcher | null {
  if (type === 'WisdomTree' && (subtype === 'variableNav' || subtype === 'fixedNav')) {
    return fetchWisdomTreeVariableNav
  }
  return null
}

export type { OracleData } from './wisdomtree-variable-nav'
