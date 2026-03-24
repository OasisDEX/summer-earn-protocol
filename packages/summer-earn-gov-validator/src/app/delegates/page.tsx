import { formatUnits } from 'ethers'

import { DashboardLayout } from '@/components/DashboardLayout'
import { DelegatesList } from '@/components/DelegatesList'
import { resolveEnsNames } from '@/services/ens'
import { Delegate } from '@/services/mockData'
import { fetchDelegates } from '@/services/subgraph'

// Revalidate every hour (delegates don't change often)
export const revalidate = 3600

async function getDelegates(): Promise<Delegate[]> {
  try {
    const subgraphDelegates = await fetchDelegates()
    const addresses = subgraphDelegates.map((d) => d.id)
    const ensMap = await resolveEnsNames(addresses)

    return subgraphDelegates.map((d) => {
      const address = d.id.toLowerCase()
      const ensName = ensMap[address] || `${d.id.slice(0, 6)}...${d.id.slice(-4)}`

      return {
        ensName,
        address: d.id,
        votingPower: `${Number(formatUnits(d.votingPower, 18)).toLocaleString(undefined, {
          maximumFractionDigits: 0,
        })} SUMR`,
        proposalsVoted: d.delegationsCount,
      }
    })
  } catch (error) {
    console.error('Error fetching delegates for UI:', error)
    return []
  }
}

export default async function DelegatesPage() {
  const delegates = await getDelegates()

  return (
    <DashboardLayout activeTab="delegates">
      <DelegatesList initialDelegates={delegates} />
    </DashboardLayout>
  )
}
