/**
 * Default fetcher for oracle-cli update/start commands.
 * Uses WisdomTree/variableNav fetcher for current oracle types.
 */
import { fetchOracleData as fetchWisdomTreeVariableNav } from './fetchers/wisdomtree-variable-nav'
import type { OracleData } from './fetchers/wisdomtree-variable-nav'

export type { OracleData }

export async function fetchOracleData(ticker: string): Promise<OracleData> {
  let offchainTicker = ticker
  if (ticker === 'CRDT') offchainTicker = 'CRDYX'
  if (ticker === 'EPXC') offchainTicker = 'WTPIX'

  const data = await fetchWisdomTreeVariableNav(offchainTicker)
  return { ...data, ticker }
}
