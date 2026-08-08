import Link from 'next/link'
import Markdown from 'react-markdown'
import { notFound } from 'next/navigation'
import rehypeRaw from 'rehype-raw'
import remarkGfm from 'remark-gfm'

import { DashboardLayout } from '@/components/DashboardLayout'
import { ProposalExecutionDetails } from '@/components/ProposalExecutionDetails'
import { ProposalVotingInfo } from '@/components/ProposalVotingInfo'
import { RecentVotes } from '@/components/RecentVotes'
import { getEnsNamesCached } from '@/services/ens-cached'
import { getProposalByIdCached } from '@/services/subgraph-cached'
import { SupportedNetworks } from '@/services/validation'
import { FinalStatus } from '@/types/governance'
import { transformProposal } from '@/utils/proposal-transformer'
import { convertRawUrlsToMarkdown } from '@/utils/text'
import { formatTimestamp } from '@/utils/timing'

import delegatesData from '../../../../../delegates.json'

function resolveDelegateInfo(address: string) {
  const nodes = delegatesData.data.delegates.nodes
  return nodes.find((node) => node.account.address.toLowerCase() === address.toLowerCase())?.account
}

// Same status -> color mapping used in ProposalsList.tsx and /proposal/[id].
function getStatusStyle(status: string) {
  switch (status) {
    case 'Active':
    case 'Executed':
      return { bg: 'var(--okBg)', fg: 'var(--ok)' }
    case 'Executed on Hub':
    case 'Queued':
      return { bg: 'var(--warnBg)', fg: 'var(--warn)' }
    case 'Defeated':
      return { bg: 'var(--critBg)', fg: 'var(--crit)' }
    case 'Pending':
      return { bg: 'var(--infoBg)', fg: 'var(--info)' }
    case 'Canceled':
    default:
      return { bg: 'var(--surface3)', fg: 'var(--fg3)' }
  }
}

const PHASES: { label: string }[] = [
  { label: 'Pending' },
  { label: 'Active' },
  { label: 'Succeeded' },
  { label: 'Queued' },
  { label: 'Executed' },
]

function getPhaseIndex(status: FinalStatus): number {
  switch (status) {
    case 'Pending':
      return 0
    case 'Active':
      return 1
    case 'Succeeded':
      return 2
    case 'Queued':
      return 3
    case 'Executed':
    case 'Executed on Hub':
      return 4
    default:
      // Defeated / Canceled are terminal, non-progressing states.
      return -1
  }
}

function PhaseTimeline({ status }: { status: FinalStatus }) {
  const currentIndex = getPhaseIndex(status)

  return (
    <div className="flex items-start gap-0 px-5 py-4 border-t border-line overflow-x-auto">
      {/* The terminal phase (Executed) has no "next" step pending, so it renders
          as done/green rather than current/pink — otherwise a fully executed
          proposal's last node looks like it's still in progress. */}
      {PHASES.map((phase, i) => {
        // "Executed on Hub" shares the same phase index as "Executed" but the
        // satellite legs are still pending, so only the fully-executed status
        // should render the last node as done/green.
        const isTerminalDone = status === 'Executed' && currentIndex === PHASES.length - 1
        const state =
          i < currentIndex || (isTerminalDone && i === currentIndex)
            ? 'done'
            : i === currentIndex
              ? 'current'
              : 'future'
        const nodeClass =
          state === 'future'
            ? 'bg-surface3 text-fg3'
            : state === 'current'
              ? 'bg-brand-pink text-white'
              : 'bg-ok text-white'
        const barClass =
          state === 'done' ? 'bg-ok' : state === 'current' ? 'bg-brand-pink' : 'bg-line2'
        const labelClass = state === 'future' ? 'text-fg3' : 'text-fg'

        return (
          <div key={phase.label} className="flex-1 min-w-[96px] flex flex-col gap-2">
            <div className="flex items-center gap-2">
              <span
                className={`shrink-0 w-[22px] h-[22px] rounded-full flex items-center justify-center font-mono text-[11px] font-semibold ${nodeClass}`}
              >
                {i + 1}
              </span>
              <span className={`flex-1 h-0.5 rounded-full ${barClass}`} />
            </div>
            <span className={`text-[11px] font-semibold ${labelClass}`}>{phase.label}</span>
          </div>
        )
      })}
    </div>
  )
}

interface PageProps {
  params: Promise<{ id: string }>
}

export default async function V1ProposalDetailPage({ params }: PageProps) {
  const { id } = await params
  const fullProposal = await getProposalByIdCached(id, true)

  if (!fullProposal) {
    notFound()
  }

  const proposal = transformProposal(fullProposal)

  const voterAddresses = proposal.votes.map((v) => v.voter)
  // Normalize (dedupe + sort) so the ENS cache key is independent of voter order.
  const ensMap = await getEnsNamesCached([...new Set(voterAddresses)].sort())

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
  const statusStyle = getStatusStyle(proposal.status)
  const displayId = proposal.displayId || proposal.id.slice(0, 8)

  return (
    <DashboardLayout activeTab="proposals">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center gap-2.5 text-xs text-fg3 mb-3.5">
          <Link href="/proposals" className="text-fg2 hover:text-fg transition-colors">
            Proposals
          </Link>
          <span>/</span>
          <span className="font-mono text-fg">{displayId}</span>
        </div>

        <div className="relative border border-line rounded-xl bg-console-surface overflow-hidden mb-4">
          <span
            className="absolute left-0 top-7 w-[3px] h-14 rounded-r-full"
            style={{ background: statusStyle.fg }}
          />
          <div className="px-5 py-[18px]">
            <div className="mb-3">
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-warn-bg border border-warn/20 text-warn text-[10px] font-bold uppercase tracking-widest">
                V1 Archive
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-2.5 mb-2.5">
              <span className="font-mono text-xs font-semibold text-brand-pink">{displayId}</span>
              <span
                className="px-2 py-0.5 rounded text-[10px] font-semibold tracking-wider uppercase"
                style={{ background: statusStyle.bg, color: statusStyle.fg }}
              >
                {proposal.status}
              </span>
              <span className="px-2 py-0.5 rounded text-[10px] font-semibold tracking-wider bg-surface3 text-fg2">
                {proposal.chain}
              </span>
              <span className="ml-auto font-mono text-[11px] text-fg3">
                Created {formatTimestamp(proposal.createdAt)}
              </span>
            </div>
            <h1 className="m-0 text-2xl font-semibold tracking-[-0.03em] text-fg text-pretty">
              {proposal.title}
            </h1>
          </div>

          <PhaseTimeline status={proposal.status} />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
          {/* Main Content */}
          <div className="lg:col-span-7 flex flex-col gap-3.5 min-w-0">
            <section className="border border-line rounded-xl bg-console-surface p-5">
              <div className="text-fg2 text-[13px] leading-[1.75] space-y-2.5">
                <Markdown
                  remarkPlugins={[remarkGfm]}
                  rehypePlugins={[rehypeRaw]}
                  components={{
                    h1: ({ children }) => (
                      <h1 className="text-xl font-semibold tracking-[-0.02em] text-fg mb-2 mt-5">
                        {children}
                      </h1>
                    ),
                    h2: ({ children }) => (
                      <h2 className="text-lg font-semibold tracking-[-0.02em] text-fg mb-2 mt-4">
                        {children}
                      </h2>
                    ),
                    h3: ({ children }) => (
                      <h3 className="text-base font-semibold text-fg mb-2 mt-3">{children}</h3>
                    ),
                    p: ({ children }) => <p className="mb-2.5">{children}</p>,
                    ul: ({ children }) => (
                      <ul className="list-disc list-inside mb-2.5 space-y-1.5">{children}</ul>
                    ),
                    ol: ({ children }) => (
                      <ol className="list-decimal list-inside mb-2.5 space-y-1.5">{children}</ol>
                    ),
                    li: ({ children }) => <li className="text-fg2">{children}</li>,
                    img: ({ ...props }) => (
                      <span className="block my-4 overflow-hidden rounded-lg border border-line">
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
                        className="text-brand-pink hover:underline"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        {children}
                      </a>
                    ),
                    strong: ({ children }) => (
                      <strong className="font-semibold text-fg">{children}</strong>
                    ),
                    em: ({ children }) => <em className="italic">{children}</em>,
                    code: ({ children }) => (
                      <code className="bg-field px-1 py-0.5 rounded text-xs font-mono text-fg2">
                        {children}
                      </code>
                    ),
                    pre: ({ children }) => (
                      <pre className="bg-field border border-line p-3.5 rounded-lg overflow-x-auto mb-2.5 text-xs">
                        {children}
                      </pre>
                    ),
                    blockquote: ({ children }) => (
                      <blockquote className="border-l-2 border-brand-pink bg-surface2 rounded-r-lg pl-3.5 py-2 italic text-fg2 mb-2.5">
                        {children}
                      </blockquote>
                    ),
                    table: ({ children }) => (
                      <div className="overflow-x-auto mb-3 border border-line rounded-lg">
                        <table className="min-w-full divide-y divide-line">{children}</table>
                      </div>
                    ),
                    thead: ({ children }) => <thead className="bg-surface2">{children}</thead>,
                    tbody: ({ children }) => (
                      <tbody className="divide-y divide-line">{children}</tbody>
                    ),
                    tr: ({ children }) => (
                      <tr className="hover:bg-surface2 transition-colors">{children}</tr>
                    ),
                    th: ({ children }) => (
                      <th className="px-3.5 py-2.5 text-left text-[10px] font-semibold text-fg3 uppercase tracking-[0.07em]">
                        {children}
                      </th>
                    ),
                    td: ({ children }) => (
                      <td className="px-3.5 py-2.5 text-xs font-mono text-fg2 whitespace-nowrap">
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
            <section className="border border-line rounded-xl bg-console-surface overflow-hidden">
              <div className="px-4 py-3.5 border-b border-line text-[13px] font-semibold text-fg">
                Proposed actions
              </div>
              <div className="p-4">
                <ProposalExecutionDetails
                  baseProposal={fullProposal.baseProposal}
                  crossChainProposals={fullProposal.crossChainProposals}
                  network={network}
                />
              </div>
            </section>
          </div>

          {/* Sidebar */}
          <div className="lg:col-span-5 min-w-0">
            <div className="sticky top-28 flex flex-col gap-3.5 min-w-0">
              <section className="border border-line rounded-xl bg-console-surface p-[18px]">
                <div className="text-[13px] font-semibold text-fg mb-3.5">Current results</div>
                <ProposalVotingInfo proposal={proposal} displayId={displayId} />
              </section>

              {/* Recent Votes Section */}
              <RecentVotes votes={proposal.votes} voterMetadata={voterMetadata} />
            </div>
          </div>
        </div>
      </div>
    </DashboardLayout>
  )
}
