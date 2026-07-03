import { Suspense } from 'react'
import { formatUnits } from 'ethers'
import { connection } from 'next/server'

import { DashboardLayout } from '@/components/DashboardLayout'
import { DelegatesList } from '@/components/DelegatesList'
import { ProposalsListSkeleton } from '@/components/ProposalsListSkeleton'
import { getCuriaDelegates } from '@/services/curia'
import { getEnsNamesCached } from '@/services/ens-cached'
import { getDelegatesCached } from '@/services/subgraph-cached'
import { Delegate } from '@/types/governance'

import delegatesData from '../../../delegates.json'

function resolveDelegateInfo(address: string) {
  const nodes = delegatesData.data.delegates.nodes
  return nodes.find((node) => node.account.address.toLowerCase() === address.toLowerCase())?.account
}

export default function DelegatesPage() {
  return (
    <DashboardLayout activeTab="delegates">
      <Suspense fallback={<ProposalsListSkeleton />}>
        <DelegatesListServer />
      </Suspense>
    </DashboardLayout>
  )
}

async function DelegatesListServer() {
  await connection()

  let delegates: Delegate[]
  try {
    const subgraphDelegates = await getDelegatesCached()
    const addresses = subgraphDelegates.map((d) => d.id)
    // Normalize (dedupe + sort) so the ENS cache key is independent of order.
    // Curia is intentionally NOT wrapped in `use cache`: its DynamoDB layer already
    // caches for a day, and an in-process cache would pin the empty no-key result
    // for up to an hour after the CURIA_API_KEY secret is added.
    const [ensMap, curiaMap] = await Promise.all([
      getEnsNamesCached([...new Set(addresses.map((a) => a.toLowerCase()))].sort()),
      getCuriaDelegates(),
    ])

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
        curia: curiaMap[address],
      }
    })
  } catch (error) {
    console.error('Error fetching delegates for UI:', error)
    delegates = []
  }

  return <DelegatesList initialDelegates={delegates} />
}
