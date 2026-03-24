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
  Vote,
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
  quorum: number
  votes: Vote[]
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
  const { title, displayId, cleanDescription } = extractProposalMetadata(proposal.description || '')

  const forVotesValue = parseFloat(proposal.forVotes || '0') / 1e18
  const againstVotesValue = parseFloat(proposal.againstVotes || '0') / 1e18
  const quorumValue = parseFloat(proposal.quorum || '0') / 1e18

  return {
    id: proposal.id,
    displayId,
    status: finalStatus,
    chain,
    title,
    description: cleanDescription,
    quorumProgress: quorumValue > 0 ? (forVotesValue / quorumValue) * 100 : 0,
    timeRemaining: finalStatus === 'Active' ? 'Active' : finalStatus,
    forVotes: forVotesValue,
    againstVotes: againstVotesValue,
    abstainVotes: parseFloat(proposal.abstainVotes || '0') / 1e18,
    quorum: quorumValue,
    votes: proposal.votes || [],
    targets: proposal.targets || [],
    values: proposal.values || [],
    calldatas: proposal.calldatas || [],
    eta: proposal.eta || '0',
  }
}

function RecentVotes({ votes }: { votes: Vote[] }) {
  const formatWeight = (weight: string) => {
    const value = parseFloat(weight) / 1e18
    if (value >= 1000000) return `${(value / 1000000).toFixed(1)}M SUMR`
    if (value >= 1000) return `${(value / 1000).toFixed(1)}K SUMR`
    return `${value.toFixed(1)} SUMR`
  }

  const getTimeAgo = (timestamp: string) => {
    const seconds = Math.floor(Date.now() / 1000) - parseInt(timestamp)
    if (seconds < 60) return 'just now'
    const minutes = Math.floor(seconds / 60)
    if (minutes < 60) return `${minutes}m ago`
    const hours = Math.floor(minutes / 60)
    if (hours < 24) return `${hours}h ago`
    return `${Math.floor(hours / 24)}d ago`
  }

  return (
    <section className="glass-panel rounded-xl overflow-hidden shadow-2xl border border-sky-400/10">
      <div className="p-6 border-b border-sky-400/10 flex justify-between items-center bg-slate-900/40">
        <h3 className="text-lg font-semibold tracking-tight text-on-surface">Recent Votes</h3>
        <span className="text-xs font-medium text-on-surface-variant uppercase tracking-widest">
          Total: {votes.length} Addresses
        </span>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-left">
          <thead className="bg-sky-400/5 text-xs text-on-surface-variant uppercase tracking-widest">
            <tr>
              <th className="px-6 py-5 font-semibold">Voter</th>
              <th className="px-6 py-5 font-semibold">Vote</th>
              <th className="px-6 py-5 font-semibold text-right">Weight</th>
              <th className="px-6 py-5 font-semibold text-right">Time</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-sky-400/5 text-sm">
            {votes.map((vote) => (
              <tr key={vote.id} className="hover:bg-sky-400/5 transition-colors group">
                <td className="px-6 py-4 flex items-center gap-3">
                  <div
                    className={`w-8 h-8 rounded-full shadow-lg ${
                      vote.support === 1
                        ? 'bg-gradient-to-tr from-sky-400 to-tertiary shadow-sky-400/10'
                        : vote.support === 0
                          ? 'bg-gradient-to-tr from-red-400 to-orange-500 shadow-red-400/10'
                          : 'bg-gradient-to-tr from-slate-400 to-slate-600'
                    }`}
                  ></div>
                  <span className="font-medium group-hover:text-sky-300 transition-colors">
                    {vote.voter}
                  </span>
                </td>
                <td className="px-6 py-4">
                  {vote.support === 1 ? (
                    <span className="text-emerald-400 flex items-center gap-1.5 font-medium">
                      <span
                        className="material-symbols-outlined text-[18px]"
                        style={{ fontVariationSettings: "'FILL' 1" }}
                      >
                        check_circle
                      </span>
                      For
                    </span>
                  ) : vote.support === 0 ? (
                    <span className="text-error flex items-center gap-1.5 font-medium">
                      <span
                        className="material-symbols-outlined text-[18px]"
                        style={{ fontVariationSettings: "'FILL' 1" }}
                      >
                        cancel
                      </span>
                      Against
                    </span>
                  ) : (
                    <span className="text-slate-400 flex items-center gap-1.5 font-medium">
                      <span
                        className="material-symbols-outlined text-[18px]"
                        style={{ fontVariationSettings: "'FILL' 1" }}
                      >
                        do_not_disturb_on
                      </span>
                      Abstain
                    </span>
                  )}
                </td>
                <td className="px-6 py-4 text-right font-mono text-on-surface">
                  {formatWeight(vote.weight)}
                </td>
                <td className="px-6 py-4 text-right text-on-surface-variant">
                  {getTimeAgo(vote.timestamp)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="p-6 text-center border-t border-sky-400/10 bg-slate-900/20">
        <button className="px-8 py-2.5 rounded-lg border border-sky-400/30 text-sky-300 text-sm font-bold uppercase tracking-widest hover:bg-sky-400/10 hover:border-sky-400/50 transition-all active:scale-95">
          View All Votes
        </button>
      </div>
    </section>
  )
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
  {
    console.log(proposal.description)
  }
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

          {/* Recent Votes Section */}
          <RecentVotes votes={proposal.votes} />
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
