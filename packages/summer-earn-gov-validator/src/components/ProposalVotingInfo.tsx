'use client'

import { useState } from 'react'
import { keccak256, stringToBytes } from 'viem'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { VoteBar } from '@/components/VoteBar'
import config from '@/config/index.json'
import { GOVERNOR_ABI } from '@/hooks/useProposalVoting'
import { TransformedProposal } from '@/types/governance'

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
  const [showVotingModal, setShowVotingModal] = useState(false)

  const handleQueueBaseProposal = async () => {
    if (!isConnected || !address) return

    const governorAddress = (config as Record<string, any>).base?.deployedContracts?.govV2
      ?.summerGovernor?.address
    if (!governorAddress) return

    try {
      setIsExecuting(true)
      if (chainId !== 8453) await switchChain({ chainId: 8453 })

      const descriptionHash = keccak256(stringToBytes(proposal.description))

      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'queue',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          descriptionHash as `0x${string}`,
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

    const governorAddress = (config as Record<string, any>).base?.deployedContracts?.govV2
      ?.summerGovernor?.address
    if (!governorAddress) return

    try {
      setIsExecuting(true)
      if (chainId !== 8453) await switchChain({ chainId: 8453 })

      const descriptionHash = keccak256(stringToBytes(proposal.description))

      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'execute',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          descriptionHash as `0x${string}`,
        ],
      })
    } catch (error) {
      console.error('Error executing base proposal:', error)
    } finally {
      setIsExecuting(false)
    }
  }

  if (!proposal.forVotes) {
    return (
      <div className="text-center py-4 text-on-surface-variant">
        <span className="material-symbols-outlined text-2xl mb-1">info</span>
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

  return (
    <div className="space-y-4">
      <VoteBar
        for={proposal.forPercent}
        against={proposal.againstPercent}
        abstain={proposal.abstainPercent}
      />

      <div className="space-y-2 text-sm">
        <div className="flex justify-between items-center">
          <span className="text-on-surface-variant">For</span>
          <span className="font-medium text-primary">{forVotes.toLocaleString()}</span>
        </div>
        <div className="flex justify-between items-center">
          <span className="text-on-surface-variant">Against</span>
          <span className="font-medium text-tertiary">{againstVotes.toLocaleString()}</span>
        </div>
        <div className="flex justify-between items-center">
          <span className="text-on-surface-variant">Abstain</span>
          <span className="font-medium text-on-surface-variant">
            {abstainVotes.toLocaleString()}
          </span>
        </div>
        {QUORUM_THRESHOLD > 0 && (
          <div className="pt-2 mt-2 border-t border-outline/10">
            <div className="flex justify-between items-center mb-1">
              <span className="text-on-surface-variant text-xs font-bold uppercase tracking-wider">
                Quorum Progress
              </span>
              <span
                className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${
                  quorumReached
                    ? 'bg-emerald-400/10 text-emerald-400 border border-emerald-400/20 shadow-[0_0_10px_rgba(52,211,153,0.3)]'
                    : 'bg-primary/10 text-primary border border-primary/20 shadow-[0_0_8px_rgba(125,211,252,0.4)]'
                }`}
              >
                {quorumReached ? 'REACHED' : 'NOT REACHED'}
              </span>
            </div>
            <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden shadow-inner">
              <div
                className={`h-full transition-all duration-700 rounded-full ${
                  quorumReached
                    ? 'bg-emerald-400 shadow-[0_0_12px_rgba(52,211,153,0.6)]'
                    : 'bg-primary shadow-[0_0_12px_rgba(125,211,252,0.4)]'
                }`}
                style={{ width: `${proposal.quorumProgress}%` }}
              ></div>
            </div>
            <div className="flex justify-between items-center mt-1 text-[10px]">
              <span className="text-on-surface-variant">
                Threshold:{' '}
                {QUORUM_THRESHOLD.toLocaleString(undefined, { maximumFractionDigits: 0 })} SUMR
              </span>
              <span className="text-on-surface font-medium">
                {proposal.quorumProgress.toFixed(1)}%
              </span>
            </div>
          </div>
        )}
      </div>

      <div className="space-y-3 mt-4">
        {proposal.status === 'Active' ? (
          <>
            <button
              onClick={() => setShowVotingModal(true)}
              className="w-full text-center py-4 bg-primary text-on-primary rounded-xl font-bold text-lg hover:brightness-110 active:scale-[0.98] transition-all shadow-[0_0_20px_rgba(125,211,252,0.2)] flex items-center justify-center gap-2 group"
            >
              <span>Vote on {displayId || proposal.id.slice(0, 8)}</span>
              <span className="material-symbols-outlined group-hover:translate-x-1 transition-transform">
                arrow_forward
              </span>
            </button>

            <VotingModal
              proposalId={proposal.id}
              proposalTitle={proposal?.title || ''}
              isOpen={showVotingModal}
              onClose={() => setShowVotingModal(false)}
            />
          </>
        ) : proposal.status === 'Succeeded' ? (
          <button
            onClick={handleQueueBaseProposal}
            disabled={isExecuting || isPending}
            className="w-full text-center py-4 bg-primary text-on-primary rounded-xl font-bold text-lg hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50"
          >
            {isExecuting ? 'Queueing...' : 'Queue Proposal'}
          </button>
        ) : proposal.status === 'Queued' ? (
          <button
            onClick={handleExecuteBaseProposal}
            disabled={!isBaseReady || isExecuting || isPending}
            className="w-full text-center py-4 bg-primary text-on-primary rounded-xl font-bold text-lg hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50"
          >
            {!isBaseReady ? 'In Timelock' : isExecuting ? 'Executing...' : 'Execute'}
          </button>
        ) : proposal.status === 'Executed' || proposal.status === 'Executed on Hub' ? (
          <div
            className={`w-full text-center py-4 rounded-xl font-bold border ${
              proposal.status === 'Executed on Hub'
                ? 'bg-amber-400/10 text-amber-500 border-amber-400/20'
                : 'bg-emerald-400/10 text-emerald-400 border-emerald-400/20'
            }`}
          >
            {proposal.status}
          </div>
        ) : null}
      </div>
    </div>
  )
}
