import { SupportedNetworks, addresToContractName } from '@/services/validation'
import { calculateProposalTiming } from '@/utils/timing'
import { useEffect, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import styles from '../styles/Form.module.scss'
import { PhaseIndicator } from './PhaseIndicator'

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

type StatusFilter = 'pending' | 'executed' | 'canceled'

const STATUS_LABELS: Record<StatusFilter, string> = {
  pending: 'Pending',
  executed: 'Executed',
  canceled: 'Canceled',
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
  const [expandedProposal, setExpandedProposal] = useState<string | null>(null)
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

  const filteredProposals = proposals.filter(
    (proposal) => proposal.status.toLowerCase() === statusFilter,
  )

  const proposalsByStatus = filteredProposals.reduce(
    (acc, proposal) => {
      const status = proposal.status
      if (!acc[status]) {
        acc[status] = []
      }
      acc[status].push(proposal)
      return acc
    },
    {} as Record<string, Proposal[]>,
  )

  const getProposalTitle = (description: string) => {
    const firstLine = description.split('\n')[0]
    return firstLine.length > 20 ? firstLine.substring(0, 100) + '...' : firstLine
  }

  const toggleProposal = (id: string) => {
    setExpandedProposal(expandedProposal === id ? null : id)
  }

  if (loading) {
    return <div className={styles.loading}>Loading proposals...</div>
  }

  if (error) {
    return (
      <div className={styles.error}>
        <h3>Error Loading Proposals</h3>
        <p>{error}</p>
        <p>Please check the console for more details.</p>
      </div>
    )
  }

  if (proposals.length === 0) {
    return (
      <div className={styles.noProposals}>
        <h3>No Proposals Found</h3>
        <p>There are no proposals available in the subgraph.</p>
      </div>
    )
  }

  return (
    <div className={styles.proposalList}>
      <div className={styles.statusFilter}>
        {Object.entries(STATUS_LABELS).map(([status, label]) => (
          <button
            key={status}
            className={`${styles.filterButton} ${statusFilter === status ? styles.active : ''}`}
            onClick={() => setStatusFilter(status as StatusFilter)}
          >
            {label}
          </button>
        ))}
      </div>
      {proposals.map((proposal) => {
        if (proposal.status !== statusFilter) {
          return null
        }

        const isExpanded = expandedProposal === proposal.id
        const title = getProposalTitle(proposal.description)

        // Calculate timing information if createdAt is available
        const timing = proposal.createdAt
          ? calculateProposalTiming({
              status: proposal.status,
              createdAt: proposal.createdAt,
            })
          : null

        return (
          <div key={proposal.id} className={styles.proposal}>
            <div className={styles.proposalHeader} onClick={() => toggleProposal(proposal.id)}>
              <div className={styles.proposalTitle}>
                <div className="flex flex-col space-y-2">
                  <span className={styles.title}>{title}</span>
                  {timing && <PhaseIndicator timing={timing} variant="compact" />}
                </div>
                <button
                  className={styles.selectButton}
                  onClick={(e) => {
                    e.stopPropagation()
                    onSelectProposal(proposal)
                  }}
                >
                  Use this proposal
                </button>
              </div>
              <span className={styles.expandIcon}>{isExpanded ? '▼' : '▶'}</span>
            </div>
            {isExpanded && (
              <div className={styles.proposalDetails}>
                {timing && (
                  <div className="mb-4 p-4 bg-gray-50 rounded-lg">
                    <PhaseIndicator timing={timing} variant="detailed" />
                  </div>
                )}
                <div className={styles.description}>
                  <ReactMarkdown>{proposal.description}</ReactMarkdown>
                </div>
                <div className={styles.targetsList}>
                  {proposal.targets.map((target, index) => (
                    <li key={index}>
                      <span className={styles.label}>Target {index + 1}:</span>
                      <span className={styles.address}>{target}</span>
                      <span className={styles.contractName}>({contractNames[index]})</span>
                      <span className={styles.value}>{proposal.values[index]} ETH</span>
                    </li>
                  ))}
                </div>
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
