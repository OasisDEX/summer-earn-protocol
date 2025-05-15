import { useEffect, useState } from 'react';
import styles from '../styles/Form.module.scss';
import ReactMarkdown from 'react-markdown';

interface Proposal {
  id: string;
  targets: string[];
  values: string[];
  calldatas: string[];
  description: string;
  descriptionHash: string;
  status: string;
  chains: string[];
}

const SUBGRAPH_URL = 'https://subgraph.staging.oasisapp.dev/summer-protocol-gov-base';

type StatusFilter = 'all' | 'pending' | 'executed' | 'canceled';

export function ProposalList({ onSelectProposal }: { onSelectProposal: (proposal: Proposal) => void }) {
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [expandedDescription, setExpandedDescription] = useState<string | null>(null);

  useEffect(() => {
    const fetchProposals = async () => {
      try {
        console.log('Fetching proposals from:', SUBGRAPH_URL);
        
        const query = `
          {
            proposals {
              id
              targets
              values
              calldatas
              description
              descriptionHash
              status
              chains
            }
          }
        `;

        const response = await fetch(SUBGRAPH_URL, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ query }),
        });

        console.log('Response status:', response.status);
        
        if (!response.ok) {
          const errorText = await response.text();
          console.error('Error response:', errorText);
          throw new Error(`Failed to fetch proposals: ${response.status} ${errorText}`);
        }

        const data = await response.json();
        console.log('Received data:', data);
        
        if (data.errors) {
          console.error('GraphQL errors:', data.errors);
          throw new Error(data.errors[0].message);
        }

        if (!data.data || !data.data.proposals) {
          console.error('Unexpected data structure:', data);
          throw new Error('Invalid response format from subgraph');
        }

        setProposals(data.data.proposals);
      } catch (err) {
        console.error('Error fetching proposals:', err);
        setError(err instanceof Error ? err.message : 'An error occurred');
      } finally {
        setLoading(false);
      }
    };

    fetchProposals();
  }, []);

  const filteredProposals = proposals.filter(proposal => 
    statusFilter === 'all' || proposal.status.toLowerCase() === statusFilter
  );

  const proposalsByStatus = filteredProposals.reduce((acc, proposal) => {
    const status = proposal.status;
    if (!acc[status]) {
      acc[status] = [];
    }
    acc[status].push(proposal);
    return acc;
  }, {} as Record<string, Proposal[]>);

  if (loading) {
    return <div className={styles.loading}>Loading proposals...</div>;
  }

  if (error) {
    return (
      <div className={styles.error}>
        <h3>Error Loading Proposals</h3>
        <p>{error}</p>
        <p>Please check the console for more details.</p>
      </div>
    );
  }

  if (proposals.length === 0) {
    return (
      <div className={styles.noProposals}>
        <h3>No Proposals Found</h3>
        <p>There are no proposals available in the subgraph.</p>
      </div>
    );
  }

  return (
    <div className={styles.proposalList}>
      <div className={styles.statusFilter}>
        <button
          className={`${styles.filterButton} ${statusFilter === 'all' ? styles.active : ''}`}
          onClick={() => setStatusFilter('all')}
        >
          All
        </button>
        <button
          className={`${styles.filterButton} ${statusFilter === 'pending' ? styles.active : ''}`}
          onClick={() => setStatusFilter('pending')}
        >
          Pending
        </button>
        <button
          className={`${styles.filterButton} ${statusFilter === 'executed' ? styles.active : ''}`}
          onClick={() => setStatusFilter('executed')}
        >
          Executed
        </button>
        <button
          className={`${styles.filterButton} ${statusFilter === 'canceled' ? styles.active : ''}`}
          onClick={() => setStatusFilter('canceled')}
        >
          Canceled
        </button>
      </div>

      {Object.entries(proposalsByStatus).map(([status, statusProposals]) => (
        <div key={status} className={styles.proposalSection}>
          <h3>{status} Proposals ({statusProposals.length})</h3>
          {statusProposals.map((proposal) => (
            <div key={proposal.id} className={styles.proposal}>
              <div className={styles.proposalHeader}>
                <div className={styles.targetInfo}>
                  <span className={styles.label}>Targets:</span>
                  {proposal.targets.map((target, index) => (
                    <span key={index} className={styles.address}>
                      {target}
                    </span>
                  ))}
                </div>
                <div className={styles.valueInfo}>
                  <span className={styles.label}>Values:</span>
                  {proposal.values.map((value, index) => (
                    <span key={index} className={styles.value}>
                      {value}
                    </span>
                  ))}
                </div>
              </div>
              <div className={styles.description}>
                <div 
                  className={styles.descriptionPreview}
                  onClick={() => setExpandedDescription(
                    expandedDescription === proposal.id ? null : proposal.id
                  )}
                >
                  <p>{proposal.description.split('\n')[0]}...</p>
                  <span className={styles.expandIcon}>
                    {expandedDescription === proposal.id ? '▼' : '▶'}
                  </span>
                </div>
                {expandedDescription === proposal.id && (
                  <div className={styles.descriptionFull}>
                    <ReactMarkdown>{proposal.description}</ReactMarkdown>
                  </div>
                )}
              </div>
              <div className={styles.chains}>
                <span className={styles.label}>Chains:</span>
                {proposal.chains.map((chain, index) => (
                  <span key={index} className={styles.chain}>
                    {chain}
                  </span>
                ))}
              </div>
              <button
                className={styles.selectButton}
                onClick={() => onSelectProposal(proposal)}
              >
                Use This Proposal
              </button>
            </div>
          ))}
        </div>
      ))}
    </div>
  );
} 