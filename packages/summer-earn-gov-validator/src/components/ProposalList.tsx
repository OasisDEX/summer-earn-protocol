import { useEffect, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import styles from '../styles/Form.module.scss'

interface Proposal {
  id: string
  targets: string[]
  values: string[]
  calldatas: string[]
  description: string
  descriptionHash: string
  status: string
  chains: string[]
}

interface RawProposal {
  id: string
  description: string
  status: string
  targets: string[]
  values: string[]
  calldatas: string[]
}

const SUBGRAPH_URL = 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base'

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
        console.log('Fetching proposals from:', SUBGRAPH_URL)

        const query = `
          {
            proposals {
              id
              description
              status
              targets
              values
              calldatas
            }
          }
        `

        const response = await fetch(SUBGRAPH_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ query }),
        })

        console.log('Response status:', response.status)

        if (!response.ok) {
          const errorText = await response.text()
          console.error('Error response:', errorText)
          throw new Error(`Failed to fetch proposals: ${response.status} ${errorText}`)
        }

        const data = await response.json()
        console.log('Received data:', data)

        if (data.errors) {
          console.error('GraphQL errors:', data.errors)
          throw new Error(data.errors[0].message)
        }

        if (!data.data || !data.data.proposals) {
          console.error('Unexpected data structure:', data)
          throw new Error('Invalid response format from subgraph')
        }

        const fetchedProposals = data.data.proposals.map((p: RawProposal) => ({
          ...p,
          status: p.status.toLowerCase(),
        }))

        setProposals(fetchedProposals)

        // Get contract names for all targets
        const names = await Promise.all(
          fetchedProposals
            .flatMap((p: RawProposal) => p.targets)
            .map(async (target: string) => {
              try {
                const response = await fetch(
                  `https://api.etherscan.io/api?module=contract&action=getsourcecode&address=${target}&apikey=${process.env.NEXT_PUBLIC_ETHERSCAN_API_KEY}`,
                )
                const data = await response.json()
                return data.result[0]?.ContractName || 'Unknown'
              } catch (error) {
                return 'Unknown'
              }
            }),
        )
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

        return (
          <div key={proposal.id} className={styles.proposal}>
            <div className={styles.proposalHeader} onClick={() => toggleProposal(proposal.id)}>
              <div className={styles.proposalTitle}>
                <span className={styles.title}>{title}</span>
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
