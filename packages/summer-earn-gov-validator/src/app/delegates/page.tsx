import { formatUnits } from 'ethers'

import { DashboardLayout } from '@/components/DashboardLayout'
import { DelegatesList } from '@/components/DelegatesList'
import { resolveEnsNames } from '@/services/ens'
import { getDelegatesCached } from '@/services/subgraph-cached'
import { Delegate } from '@/types/governance'

import delegatesData from '../../../delegates.json'

function resolveDelegateInfo(address: string) {
  const nodes = delegatesData.data.delegates.nodes
  return nodes.find((node) => node.account.address.toLowerCase() === address.toLowerCase())?.account
}

export default async function DelegatesPage() {

  let delegates: Delegate[] = []
  try {
    const subgraphDelegates = await getDelegatesCached()
    const addresses = subgraphDelegates.map((d) => d.id)
    const ensMap = await resolveEnsNames(addresses)

    delegates = subgraphDelegates.map((d) => {
      const address = d.id.toLowerCase()
      const tallyInfo = resolveDelegateInfo(address)
      const ensName = ensMap[address] || `${d.id.slice(0, 6)}...${d.id.slice(-4)}`

      return {
        name: tallyInfo?.name || ensName,
        address: d.id,
        votingPower: `${Number(formatUnits(d.votingPower, 18)).toLocaleString(undefined, {
          maximumFractionDigits: 0,
        })} SUMR`,
        proposalsVoted: d.delegationsCount,
        bio: tallyInfo?.bio || '',
        picture: tallyInfo?.picture || null,
        twitter: tallyInfo?.twitter || '',
      }
    })
  } catch (error) {
    console.error('Error fetching delegates for UI:', error)
  }

  return (
    <DashboardLayout activeTab="delegates">
      <DelegatesList initialDelegates={delegates} />
    </DashboardLayout>
  )
}
