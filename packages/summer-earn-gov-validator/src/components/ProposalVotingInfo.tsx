'use client'

import { useState } from 'react'
import { useAccount, useReadContract, useSwitchChain, useWriteContract } from 'wagmi'
import { ArrowRight, Clock } from 'lucide-react'

import { GOVERNOR_ABI } from '@/hooks/useProposalVoting'
import { TransformedProposal } from '@/types/governance'
import { formatTimeRemaining } from '@/utils/timing'

import { VotingModal } from './VotingModal'

interface ProposalVotingInfoProps {
  proposal: TransformedProposal
  displayId?: string | null
}

export function ProposalVotingInfo({ proposal, displayId }: ProposalVotingInfoProps) {
  const { address, isConnected, chainId } = useAccount()
  const { writeContract, isPending } = useWriteContract()
  const { switchChain } = useSwitchChain()
  const [isExecuting, setIsExecuting] = useState(false)
  const [isCancelling, setIsCancelling] = useState(false)
  const [showVotingModal, setShowVotingModal] = useState(false)

  // A proposal can only be cancelled before it reaches a terminal state.
  const isCancellableStatus = ['Pending', 'Active', 'Succeeded', 'Queued'].includes(proposal.status)

  // The subgraph does not index the proposer, so read it on-chain from the hub
  // (Base) governor. SummerGovernorV2.cancel always allows the original proposer.
  const { data: proposer } = useReadContract({
    address: proposal.governor as `0x${string}`,
    abi: GOVERNOR_ABI,
    functionName: 'proposalProposer',
    args: [BigInt(proposal.id)],
    chainId: 8453,
    query: { enabled: isCancellableStatus && !!proposal.governor },
  })

  const isProposer =
    !!address && !!proposer && address.toLowerCase() === (proposer as string).toLowerCase()

  const handleCancelProposal = async () => {
    if (!isConnected || !address) return

    const governorAddress = proposal.governor
    if (!governorAddress) return

    try {
      setIsCancelling(true)
      if (chainId !== 8453) await switchChain({ chainId: 8453 })
      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'cancel',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          proposal.descriptionHash,
        ],
      })
    } catch (error) {
      console.error('Error cancelling proposal:', error)
    } finally {
      setIsCancelling(false)
    }
  }

  const cancelButton = isCancellableStatus ? (
    <div className="space-y-1">
      <button
        onClick={handleCancelProposal}
        disabled={!isConnected || !isProposer || isCancelling || isPending}
        className="w-full text-center py-2.5 border border-crit bg-crit-bg text-crit rounded-lg text-xs font-semibold hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isCancelling ? 'Cancelling...' : 'Cancel proposal'}
      </button>
      {isConnected && !isProposer && (
        <p className="text-[10px] text-center text-fg3">Only the proposer can cancel</p>
      )}
    </div>
  ) : null

  const handleQueueBaseProposal = async () => {
    if (!isConnected || !address) return

    const governorAddress = proposal.governor
    if (!governorAddress) return

    try {
      setIsExecuting(true)
      if (chainId !== 8453) await switchChain({ chainId: 8453 })
      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'queue',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          proposal.descriptionHash,
        ],
      })
    } catch (error) {
      console.error('Error queueing base proposal:', error)
    } finally {
      setIsExecuting(false)
    }
  }

  const handleExecuteBaseProposal = async () => {
    if (!isConnected || !address || !proposal) return

    const governorAddress = proposal.governor
    if (!governorAddress) return

    try {
      setIsExecuting(true)
      if (chainId !== 8453) await switchChain({ chainId: 8453 })

      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'execute',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          proposal.descriptionHash,
        ],
      })
    } catch (error) {
      console.error('Error executing base proposal:', error)
    } finally {
      setIsExecuting(false)
    }
  }

  if (proposal.status === 'Pending') {
    return (
      <div className="text-center py-6">
        <Clock className="w-8 h-8 mx-auto mb-3 text-fg3" />
        <h3 className="text-[10px] font-semibold uppercase tracking-[0.15em] text-fg3 mb-2">
          Voting starts in
        </h3>
        <p className="text-2xl font-mono font-semibold text-fg tracking-tight">
          {formatTimeRemaining(proposal.timeRemaining)}
        </p>
        {cancelButton && <div className="mt-5">{cancelButton}</div>}
      </div>
    )
  }

  if (!proposal.forVotes && proposal.status !== 'Active') {
    return (
      <div className="text-center py-4 text-fg3 text-xs">
        <p>Vote data unavailable</p>
      </div>
    )
  }

  const forVotes = proposal.forVotes
  const againstVotes = proposal.againstVotes
  const abstainVotes = proposal.abstainVotes

  // Quorum from subgraph or fallback to 15% of current supply
  const QUORUM_THRESHOLD = proposal.quorum

  const quorumReached = forVotes >= QUORUM_THRESHOLD

  const baseEta = Number(proposal?.eta || 0)
  const currentTimestamp = Math.floor(Date.now() / 1000)
  const isBaseReady = proposal.status === 'Queued' && baseEta > 0 && currentTimestamp >= baseEta

  const tally: { label: string; value: number; percent: number; barClass: string }[] = [
    { label: 'For', value: forVotes, percent: proposal.forPercent, barClass: 'bg-ok' },
    {
      label: 'Against',
      value: againstVotes,
      percent: proposal.againstPercent,
      barClass: 'bg-crit',
    },
    { label: 'Abstain', value: abstainVotes, percent: proposal.abstainPercent, barClass: 'bg-fg3' },
  ]

  return (
    <div className="space-y-4">
      {QUORUM_THRESHOLD > 0 && (
        <div>
          <div className="flex items-baseline justify-between gap-2.5 mb-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.07em] text-fg3">
              Quorum {quorumReached ? 'reached' : 'not reached'}
            </span>
            <span className="font-mono text-xs text-fg3">
              {proposal.quorumProgress.toFixed(1)}%
            </span>
          </div>
          <div className="h-1.5 rounded-full bg-surface3 overflow-hidden">
            <div
              className="h-full rounded-full bg-brand-gradient transition-all duration-700"
              style={{ width: `${Math.min(proposal.quorumProgress, 100)}%` }}
            />
          </div>
          <div className="font-mono text-[11px] text-fg3 mt-1.5">
            Threshold {QUORUM_THRESHOLD.toLocaleString(undefined, { maximumFractionDigits: 0 })}{' '}
            SUMR
          </div>
        </div>
      )}

      <div className="space-y-2.5">
        {tally.map((row) => (
          <div key={row.label}>
            <div className="flex justify-between gap-2.5 text-[11px] mb-1">
              <span className="text-fg2">{row.label}</span>
              <span className="font-mono text-fg3">
                {row.value.toLocaleString()} · {Math.round(row.percent)}%
              </span>
            </div>
            <div className="h-1 rounded-full bg-surface3 overflow-hidden">
              <div
                className={`h-full rounded-full ${row.barClass}`}
                style={{ width: `${row.percent}%` }}
              />
            </div>
          </div>
        ))}
      </div>

      <div className="flex justify-between gap-2.5 flex-wrap font-mono text-[11px] text-fg3 pt-2.5 border-t border-line">
        <span>{(forVotes + againstVotes + abstainVotes).toLocaleString()} votes</span>
        {proposal.status === 'Active' && (
          <span>{formatTimeRemaining(proposal.timeRemaining)} left</span>
        )}
      </div>

      <div className="space-y-2 pt-1">
        {proposal.status === 'Active' ? (
          <>
            <button
              onClick={() => setShowVotingModal(true)}
              className="w-full text-center py-3 bg-brand-gradient text-white rounded-lg font-semibold text-sm hover:brightness-110 active:scale-[0.98] transition-all flex items-center justify-center gap-2 group"
            >
              <span>Vote on {displayId || proposal.id.slice(0, 8)}</span>
              <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
            </button>

            <VotingModal
              proposalId={proposal.id}
              proposalTitle={proposal?.title || ''}
              governor={proposal.governor}
              isOpen={showVotingModal}
              onClose={() => setShowVotingModal(false)}
            />
          </>
        ) : proposal.status === 'Succeeded' ? (
          <button
            onClick={handleQueueBaseProposal}
            disabled={isExecuting || isPending}
            className="w-full text-center py-3 bg-brand-gradient text-white rounded-lg font-semibold text-sm hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50"
          >
            {isExecuting ? 'Queueing...' : 'Queue proposal'}
          </button>
        ) : proposal.status === 'Queued' ? (
          <button
            onClick={handleExecuteBaseProposal}
            disabled={!isBaseReady || isExecuting || isPending}
            className="w-full text-center py-3 bg-brand-gradient text-white rounded-lg font-semibold text-sm hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50"
          >
            {!isBaseReady ? 'In timelock' : isExecuting ? 'Executing...' : 'Execute'}
          </button>
        ) : proposal.status === 'Executed' || proposal.status === 'Executed on Hub' ? (
          <div
            className={`w-full text-center py-2.5 rounded-lg text-xs font-semibold uppercase tracking-wider ${
              proposal.status === 'Executed on Hub' ? 'bg-warn-bg text-warn' : 'bg-ok-bg text-ok'
            }`}
          >
            {proposal.status}
          </div>
        ) : null}

        {cancelButton}
      </div>
    </div>
  )
}
