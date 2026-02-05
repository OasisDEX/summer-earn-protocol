import { useEffect, useState } from 'react'

import { addresToContractName, SupportedNetworks } from '@/services/validation'
import { calculateProposalTiming } from '@/utils/timing'

import { PhaseIndicator } from './PhaseIndicator'
import { ProposalModal } from './ProposalModal'

interface Proposal {
  id: string
  targets: string[]
  values: string[]
  calldatas: string[]
  description: string
  descriptionHash: string
  status: string
  chains: string[]
  createdAt?: string
}

interface RawProposal {
  id: string
  description: string
  status: string
  targets: string[]
  values: string[]
  calldatas: string[]
  createdAt?: string
}

type StatusFilter = 'pending' | 'executed' | 'canceled' | 'queued'

const STATUS_LABELS: Record<StatusFilter, string> = {
  pending: 'Pending',
  executed: 'Executed',
  canceled: 'Canceled',
  queued: 'Queued',
}

export function ProposalList({
  onSelectProposal,
}: {
  onSelectProposal: (proposal: Proposal) => void
}) {
  const [proposals, setProposals] = useState<Proposal[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('pending')
  const [selectedProposal, setSelectedProposal] = useState<Proposal | null>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [contractNames, setContractNames] = useState<string[]>([])

  useEffect(() => {
    const fetchProposals = async () => {
      try {
        const start = Date.now()
        const response = await fetch('/api/proposals')
        const end = Date.now()
        console.log(`Time taken: ${end - start}ms`)

        if (!response.ok) {
          const errorData = await response.json()
          throw new Error(errorData.error || 'Failed to fetch proposals')
        }

        const data = await response.json()
        const fetchedProposals = data.proposals.map((p: RawProposal) => ({
          ...p,
          status: p.status.toLowerCase(),
        }))

        setProposals(fetchedProposals)

        // Get contract names for all targets
        const names = fetchedProposals
          .flatMap((p: RawProposal) => p.targets)
          .map((target: string) => {
            return addresToContractName(target, SupportedNetworks.BASE)
          })
        setContractNames(names)
      } catch (err) {
        console.error('Error fetching proposals:', err)
        setError(err instanceof Error ? err.message : 'An error occurred')
      } finally {
        setLoading(false)
      }
    }

    fetchProposals()
  }, [])

  const getProposalTitle = (description: string) => {
    const firstLine = description.split('\n')[0]
    return firstLine.length > 20 ? firstLine.substring(0, 100) + '...' : firstLine
  }

  const openModal = (proposal: Proposal) => {
    setSelectedProposal(proposal)
    setIsModalOpen(true)
  }

  const closeModal = () => {
    setIsModalOpen(false)
    setSelectedProposal(null)
  }

  if (loading) {
    return (
      <div className="text-center p-8 text-gray-500 dark:text-gray-400 text-lg">
        Loading proposals...
      </div>
    )
  }

  if (error) {
    return (
      <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl p-6 m-4 text-red-600 dark:text-red-400">
        <h3 className="text-red-700 dark:text-red-300 m-0 mb-3 text-lg font-semibold">
          Error Loading Proposals
        </h3>
        <p className="m-2 text-sm">{error}</p>
        <p className="m-2 text-sm">Please check the console for more details.</p>
      </div>
    )
  }

  if (proposals.length === 0) {
    return (
      <div className="bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-xl p-6 m-4 text-center text-gray-500 dark:text-gray-400">
        <h3 className="text-gray-800 dark:text-gray-200 m-0 mb-3 text-lg font-semibold">
          No Proposals Found
        </h3>
        <p className="m-0 text-sm">There are no proposals available in the subgraph.</p>
      </div>
    )
  }

  return (
    <div className="mt-8 flex flex-col gap-6">
      <div className="flex gap-4 mb-8 p-4 bg-gray-100 dark:bg-gray-800 rounded-lg">
        {Object.entries(STATUS_LABELS).map(([status, label]) => (
          <button
            key={status}
            className={`px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 cursor-pointer transition-all duration-200 hover:bg-gray-50 dark:hover:bg-gray-600 ${
              statusFilter === status
                ? 'bg-blue-600 dark:bg-blue-700 text-white border-blue-600 dark:border-blue-700'
                : 'text-gray-700 dark:text-gray-300'
            }`}
            onClick={() => setStatusFilter(status as StatusFilter)}
          >
            {label}
          </button>
        ))}
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {proposals.map((proposal) => {
          if (proposal.status !== statusFilter) {
            return null
          }

          const title = getProposalTitle(proposal.description)

          // Calculate timing information if createdAt is available
          const timing = proposal.createdAt
            ? calculateProposalTiming({
                status: proposal.status,
                createdAt: proposal.createdAt,
              })
            : null

          return (
            <div
              key={proposal.id}
              className="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 transition-all duration-200 overflow-hidden h-fit hover:shadow-md"
            >
              <div
                className="p-3 cursor-pointer transition-colors duration-200 flex flex-col gap-2 hover:bg-gray-50 dark:hover:bg-gray-700"
                onClick={() => openModal(proposal)}
              >
                <div className="flex flex-col gap-1 flex-1 min-w-0">
                  <span className="text-sm font-medium text-gray-900 dark:text-white leading-tight whitespace-nowrap overflow-hidden text-ellipsis">
                    {title}
                  </span>
                  {timing && <PhaseIndicator timing={timing} variant="compact" />}
                </div>
                <div className="flex items-center justify-between gap-2">
                  <button
                    className="px-3 py-1.5 bg-blue-600 text-white border-none rounded cursor-pointer text-xs font-medium transition-colors duration-200 flex-shrink-0 hover:bg-blue-700"
                    onClick={(e) => {
                      e.stopPropagation()
                      onSelectProposal(proposal)
                    }}
                  >
                    Use this proposal
                  </button>
                  <span className="text-gray-500 dark:text-gray-400 text-xs flex-shrink-0">👁️</span>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      <ProposalModal
        proposal={selectedProposal}
        contractNames={contractNames}
        isOpen={isModalOpen}
        onClose={closeModal}
      />
    </div>
  )
}
