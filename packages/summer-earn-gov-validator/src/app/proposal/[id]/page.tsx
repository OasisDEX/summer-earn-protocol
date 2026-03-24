import Markdown from 'react-markdown'
import { notFound } from 'next/navigation'
import rehypeRaw from 'rehype-raw'
import remarkGfm from 'remark-gfm'

import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalExecutionDetails } from '@/components/ProposalExecutionDetails'
import { ProposalVotingInfo } from '@/components/ProposalVotingInfo'
import { getChainNameById, HUB_CHAIN_ID } from '@/config/chains'
import {
  CrossChainProposal,
  fetchProposalWithCrossChainById,
  ProposalWithCrossChain,
} from '@/services/subgraph'
import { SupportedNetworks } from '@/services/validation'
import { convertRawUrlsToMarkdown, extractProposalMetadata } from '@/utils/text'

interface PageProps {
  params: Promise<{ id: string }>
}

// Transform subgraph proposal to our format
interface TransformedProposal {
  id: string
  displayId: string | null
  status: 'Active' | 'Executed' | 'Queued' | 'Defeated' | 'Succeeded' | 'Executed on Hub'
  chain: string
  title: string
  description: string
  quorumProgress: number
  timeRemaining: string
  forVotes: number
  againstVotes: number
  abstainVotes: number
  targets: string[]
  values: string[]
  calldatas: string[]
  eta: string
}

function transformProposal(proposalWithCrossChain: ProposalWithCrossChain): TransformedProposal {
  const proposal = proposalWithCrossChain.baseProposal
  const statusMap: Record<string, TransformedProposal['status']> = {
    Active: 'Active',
    Executed: 'Executed',
    Queued: 'Queued',
    Defeated: 'Defeated',
    Canceled: 'Defeated',
    Pending: 'Active',
    Succeeded: 'Succeeded',
  }

  let finalStatus = statusMap[proposal.status] || 'Active'
  if (finalStatus === 'Executed' && proposalWithCrossChain.crossChainProposals.length > 0) {
    const hasPendingCrossChain = proposalWithCrossChain.crossChainProposals.some(
      (ccp: CrossChainProposal) => ccp.status !== 'Executed',
    )
    if (hasPendingCrossChain) {
      finalStatus = 'Executed on Hub'
    }
  }

  const chains = [...proposal.chains, HUB_CHAIN_ID]
  const chain = chains.map((chainId) => getChainNameById(chainId)).join(', ')

  // Extract title and displayId from description
  const { title, displayId } = extractProposalMetadata(proposal.description || '')

  return {
    id: proposal.id,
    displayId,
    status: finalStatus,
    chain,
    title,
    description: proposal.description || '',
    quorumProgress: 0,
    timeRemaining: finalStatus === 'Active' ? 'Active' : finalStatus,
    forVotes: 0,
    againstVotes: 0,
    abstainVotes: 0,
    targets: proposal.targets || [],
    values: proposal.values || [],
    calldatas: proposal.calldatas || [],
    eta: proposal.eta || '0',
  }
}

async function getProposal(id: string): Promise<ProposalWithCrossChain | null> {
  return await fetchProposalWithCrossChainById(id)
}

export default async function ProposalDetailPage({ params }: PageProps) {
  const { id } = await params
  const fullProposal = await getProposal(id)

  if (!fullProposal) {
    notFound()
  }

  const proposal = transformProposal(fullProposal)

  // Get network from chain
  const getNetwork = (chain: string): SupportedNetworks => {
    switch (chain.toLowerCase()) {
      case 'ethereum':
      case 'mainnet':
        return SupportedNetworks.MAINNET
      case 'base':
        return SupportedNetworks.BASE
      case 'arbitrum':
        return SupportedNetworks.ARBITRUM
      case 'sonic':
        return SupportedNetworks.SONIC
      default:
        return SupportedNetworks.BASE
    }
  }

  const network = getNetwork(proposal.chain)
  const getBarColor = (status: string) => {
    switch (status) {
      case 'Active':
        return 'bg-primary shadow-[0_0_15px_rgba(125,211,252,0.4)]'
      case 'Executed':
      case 'Succeeded':
        return 'bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.4)]'
      case 'Executed on Hub':
        return 'bg-amber-400 shadow-[0_0_15px_rgba(251,191,36,0.4)]'
      case 'Queued':
        return 'bg-tertiary shadow-[0_0_15px_rgba(200,160,240,0.4)]'
      case 'Defeated':
      case 'Canceled':
        return 'bg-error shadow-[0_0_15px_rgba(255,107,107,0.4)]'
      default:
        return 'bg-slate-500 shadow-[0_0_15px_rgba(100,116,139,0.4)]'
    }
  }

  return (
    <DashboardLayout activeTab="proposals">
      <div className="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Main Content */}
        <div className="lg:col-span-8 space-y-8">
          <section className="glass-panel p-8 rounded-xl relative overflow-hidden">
            {/* Partial Frame / Status Bar */}
            <div
              className={`absolute left-0 top-1/2 -translate-y-1/2 w-1 h-[40%] rounded-r-full ${getBarColor(
                proposal.status,
              )}`}
            />
            <div className="flex flex-wrap items-center gap-3 mb-4">
              <span className="text-on-surface-variant text-sm font-bold tracking-widest uppercase">
                {proposal.displayId || proposal.id.slice(0, 8)}
              </span>
              <span
                className={`px-2 py-1 rounded border text-xs font-bold ${
                  proposal.status === 'Active'
                    ? 'bg-primary/10 text-primary border-primary/20'
                    : proposal.status === 'Executed'
                      ? 'bg-emerald-400/10 text-emerald-400 border-emerald-400/20'
                      : proposal.status === 'Executed on Hub'
                        ? 'bg-amber-400/10 text-amber-500 border-amber-400/20'
                        : 'bg-tertiary/10 text-tertiary border-tertiary/20'
                }`}
              >
                {proposal.status.toUpperCase()}
              </span>
              <span className="flex items-center gap-1 text-xs text-on-surface-variant">
                <span className="material-symbols-outlined text-sm">hub</span>
                {proposal.chain}
              </span>
            </div>
            <h1 className="text-4xl font-extrabold text-on-surface tracking-tighter mb-6">
              {proposal.title}
            </h1>
            <div className="text-on-surface-variant leading-relaxed space-y-4">
              <Markdown
                remarkPlugins={[remarkGfm]}
                rehypePlugins={[rehypeRaw]}
                components={{
                  h1: ({ children }) => (
                    <h1 className="text-2xl font-bold text-on-surface mb-4 mt-6">{children}</h1>
                  ),
                  h2: ({ children }) => (
                    <h2 className="text-xl font-semibold text-on-surface mb-3 mt-5">{children}</h2>
                  ),
                  h3: ({ children }) => (
                    <h3 className="text-lg font-medium text-on-surface mb-2 mt-4">{children}</h3>
                  ),
                  p: ({ children }) => <p className="mb-3">{children}</p>,
                  ul: ({ children }) => (
                    <ul className="list-disc list-inside mb-3 space-y-2">{children}</ul>
                  ),
                  ol: ({ children }) => (
                    <ol className="list-decimal list-inside mb-3 space-y-2">{children}</ol>
                  ),
                  li: ({ children }) => <li className="text-on-surface-variant">{children}</li>,
                  img: ({ ...props }) => (
                    <span className="block my-6 overflow-hidden rounded-xl border border-outline/10 shadow-lg">
                      <img
                        {...(props as any)}
                        className="max-w-full h-auto mx-auto"
                        alt={props.alt || 'Proposal Image'}
                      />
                    </span>
                  ),
                  a: ({ href, children }) => (
                    <a
                      href={href}
                      className="text-primary hover:underline"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {children}
                    </a>
                  ),
                  strong: ({ children }) => (
                    <strong className="font-semibold text-on-surface">{children}</strong>
                  ),
                  em: ({ children }) => <em className="italic">{children}</em>,
                  code: ({ children }) => (
                    <code className="bg-surface-container-low px-1 py-0.5 rounded text-sm font-mono">
                      {children}
                    </code>
                  ),
                  pre: ({ children }) => (
                    <pre className="bg-surface-container-low p-4 rounded-lg overflow-x-auto mb-3">
                      {children}
                    </pre>
                  ),
                  blockquote: ({ children }) => (
                    <blockquote className="border-l-4 border-primary pl-4 italic text-on-surface-variant mb-3">
                      {children}
                    </blockquote>
                  ),
                  table: ({ children }) => (
                    <div className="overflow-x-auto mb-4 border border-outline/10 rounded-xl">
                      <table className="min-w-full divide-y divide-outline/10">{children}</table>
                    </div>
                  ),
                  thead: ({ children }) => (
                    <thead className="bg-surface-container-low">{children}</thead>
                  ),
                  tbody: ({ children }) => (
                    <tbody className="divide-y divide-outline/10">{children}</tbody>
                  ),
                  tr: ({ children }) => (
                    <tr className="hover:bg-surface-container-low transition-colors">{children}</tr>
                  ),
                  th: ({ children }) => (
                    <th className="px-4 py-3 text-left text-xs font-bold text-on-surface uppercase tracking-wider">
                      {children}
                    </th>
                  ),
                  td: ({ children }) => (
                    <td className="px-4 py-3 text-sm text-on-surface-variant whitespace-nowrap">
                      {children}
                    </td>
                  ),
                }}
              >
                {convertRawUrlsToMarkdown(proposal.description)}
              </Markdown>
            </div>
          </section>

          {/* Actions Section with Decoded Calldata */}
          <section className="glass-panel p-8 rounded-xl">
            <h3 className="text-lg font-semibold mb-6 flex items-center gap-2">
              <span className="material-symbols-outlined text-primary">description</span>
              Proposal Actions
            </h3>

            <ProposalExecutionDetails
              baseProposal={fullProposal.baseProposal}
              crossChainProposals={fullProposal.crossChainProposals}
              network={network}
            />
          </section>
        </div>

        {/* Sidebar */}
        <div className="lg:col-span-4 space-y-6">
          <section className="glass-panel-elevated p-6 rounded-xl shadow-[0_0_30px_rgba(125,211,252,0.05)] sticky top-28">
            <h3 className="text-lg font-semibold mb-6">Current Results</h3>

            <ProposalVotingInfo
              proposalId={proposal.id}
              displayId={proposal.displayId || proposal.id.slice(0, 8)}
              status={proposal.status}
              proposalData={fullProposal.baseProposal}
            />
          </section>
        </div>
      </div>
    </DashboardLayout>
  )
}
