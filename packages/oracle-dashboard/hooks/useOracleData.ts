import { useQuery } from '@tanstack/react-query'
import {
  fetchOracleStats,
  NETWORK_TO_CHAIN_ID,
  type TickerStats,
  type NetworkType,
} from '../lib/oracle-data'

export type { TickerStats, NetworkType }
export { NETWORK_TO_CHAIN_ID }

export function useOracleData(selectedNetwork: NetworkType, initialData?: TickerStats[]) {
  const {
    data: stats = [],
    isLoading: loading,
    refetch,
  } = useQuery({
    queryKey: ['oracleData', selectedNetwork],
    queryFn: () => fetchOracleStats(selectedNetwork),
    initialData,
    refetchInterval: 60000,
  })

  return { stats, loading, refetch }
}
