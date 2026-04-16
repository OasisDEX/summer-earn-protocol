import Markdown from 'react-markdown'
import { notFound } from 'next/navigation'
import rehypeRaw from 'rehype-raw'
import remarkGfm from 'remark-gfm'

import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalExecutionDetails } from '@/components/ProposalExecutionDetails'
import { ProposalVotingInfo } from '@/components/ProposalVotingInfo'
import { RecentVotes } from '@/components/RecentVotes'
import { resolveEnsNames } from '@/services/ens'
import { fetchProposalWithCrossChainById } from '@/services/subgraph'
import { SupportedNetworks } from '@/services/validation'
import { ProposalWithCrossChain } from '@/types/governance'
import { transformProposal } from '@/utils/proposal-transformer'
import { convertRawUrlsToMarkdown } from '@/utils/text'

import delegatesData from '../../../../../delegates.json'

function resolveDelegateInfo(address: string) {
  const nodes = delegatesData.data.delegates.nodes
  return nodes.find((node) => node.account.address.toLowerCase() === address.toLowerCase())?.account
}

interface PageProps {
  params: Promise<{ id: string }>
}

async function getProposal(id: string): Promise<ProposalWithCrossChain | null> {
  return await fetchProposalWithCrossChainById(id, true)
}

export default async function V1ProposalDetailPage({ params }: PageProps) {
  const { id } = await params
  const fullProposal = await getProposal(id)

  if (!fullProposal) {
    notFound()
  }

  const proposal = transformProposal(fullProposal)

  // Resolve voter names
  const voterAddresses = proposal.votes.map((v) => v.voter)
  const ensMap = await resolveEnsNames(voterAddresses)
  const voterMetadata: Record<
    string,
    { name: string; picture: string | null; twitter: string | null }
  > = {}

  voterAddresses.forEach((addr) => {
    const address = addr.toLowerCase()
    const tallyInfo = resolveDelegateInfo(address)
    const name = tallyInfo?.name || ensMap[address] || `${addr.slice(0, 6)}...${addr.slice(-4)}`

    voterMetadata[address] = {
      name,
      picture: tallyInfo?.picture || null,
      twitter: tallyInfo?.twitter || null,
    }
  })
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
      case 'Pending queue':
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
            <div className="mb-6">
              <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-400/10 border border-amber-400/20 text-amber-500 text-xs font-bold uppercase tracking-widest">
                <span className="material-symbols-outlined text-sm">archive</span>
                V1 Archive
              </div>
            </div>
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
          <div className="sticky top-28 space-y-6">
            <section className="glass-panel-elevated p-6 rounded-xl shadow-[0_0_30px_rgba(125,211,252,0.05)]">
              <h3 className="text-lg font-semibold mb-6">Current Results</h3>

              <ProposalVotingInfo
                proposal={proposal}
                displayId={proposal.displayId || proposal.id.slice(0, 8)}
              />
            </section>

            {/* Recent Votes Section */}
            <RecentVotes votes={proposal.votes} voterMetadata={voterMetadata} />
          </div>
        </div>
      </div>
    </DashboardLayout>
  )
}
