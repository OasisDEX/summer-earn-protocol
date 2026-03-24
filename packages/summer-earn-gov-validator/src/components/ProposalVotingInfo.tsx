'use client'

import React, { useState } from 'react'
import { ethers, keccak256 } from 'ethers'
import Link from 'next/link'
import { toBytes } from 'viem'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { VoteBar } from '@/components/VoteBar'
import config from '@/config/index.json'
import { GOVERNOR_ABI, useProposalVoting } from '@/hooks/useProposalVoting'

interface ProposalVotingInfoProps {
  proposalId: string
  displayId?: string | null
  status: 'Active' | 'Executed' | 'Queued' | 'Defeated' | 'Succeeded' | 'Executed on Hub'
  proposalData?: {
    targets: string[]
    values: string[]
    calldatas: string[]
    description: string
    eta: string
  }
}

export function ProposalVotingInfo({
  proposalId,
  displayId,
  status,
  proposalData,
}: ProposalVotingInfoProps) {
  const { votes, totalSupply, isLoading } = useProposalVoting(proposalId)
  const { address, isConnected, chainId } = useAccount()
  const { writeContract, isPending } = useWriteContract()
  const { switchChain } = useSwitchChain()
  const [isExecuting, setIsExecuting] = useState(false)

  const handleQueueBaseProposal = async () => {
    if (!isConnected || !address || !proposalData) return

    const governorAddress = (config as any).base?.deployedContracts?.gov?.summerGovernor?.address
    if (!governorAddress) return

    try {
      setIsExecuting(true)
      if (chainId !== 8453) await switchChain({ chainId: 8453 })

      // const descriptionHash = ethers.keccak256(ethers.toUtf8Bytes(proposalData.description))
      const descriptionHash = keccak256(toBytes(proposalData.description))

      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'queue',
        args: [
          proposalData.targets as `0x${string}`[],
          proposalData.values.map((v) => BigInt(v)),
          proposalData.calldatas as `0x${string}`[],
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
    if (!isConnected || !address || !proposalData) return

    const governorAddress = (config as any).base?.deployedContracts?.gov?.summerGovernor?.address
    if (!governorAddress) return

    try {
      setIsExecuting(true)
      if (chainId !== 8453) await switchChain({ chainId: 8453 })

      // const descriptionHash = ethers.keccak256(ethers.toUtf8Bytes(proposalData.description))
      const descriptionHash = keccak256(toBytes(proposalData.description))

      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'execute',
        args: [
          proposalData.targets as `0x${string}`[],
          proposalData.values.map((v) => BigInt(v)),
          proposalData.calldatas as `0x${string}`[],
          descriptionHash as `0x${string}`,
        ],
      })
    } catch (error) {
      console.error('Error executing base proposal:', error)
    } finally {
      setIsExecuting(false)
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-4">
        <div className="flex items-center gap-2 text-on-surface-variant">
          <span className="material-symbols-outlined animate-spin">sync</span>
          <span>Loading votes...</span>
        </div>
      </div>
    )
  }

  if (!votes) {
    return (
      <div className="text-center py-4 text-on-surface-variant">
        <span className="material-symbols-outlined text-2xl mb-1">info</span>
        <p>Vote data unavailable</p>
      </div>
    )
  }

  const forVotes = Number(votes.forVotes) / 1e18
  const againstVotes = Number(votes.againstVotes) / 1e18
  const abstainVotes = Number(votes.abstainVotes) / 1e18
  const totalVotes = forVotes + againstVotes + abstainVotes

  // Quorum is 15% of total supply (dynamic from token contract)
  const QUORUM_THRESHOLD = 0.15 * (Number(totalSupply || 0) / 1e18)
  const quorumReached = forVotes >= QUORUM_THRESHOLD
  const quorumProgress =
    QUORUM_THRESHOLD > 0 ? Math.min((forVotes / QUORUM_THRESHOLD) * 100, 100) : 0

  const forPercent = totalVotes > 0 ? Math.round((forVotes / totalVotes) * 100) : 0
  const againstPercent = totalVotes > 0 ? Math.round((againstVotes / totalVotes) * 100) : 0
  const abstainPercent = totalVotes > 0 ? Math.round((abstainVotes / totalVotes) * 100) : 0

  const baseEta = Number(proposalData?.eta || 0)
  const currentTimestamp = Math.floor(Date.now() / 1000)
  const isBaseReady = status === 'Queued' && baseEta > 0 && currentTimestamp >= baseEta

  return (
    <div className="space-y-4">
      <VoteBar for={forPercent} against={againstPercent} abstain={abstainPercent} />

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
                style={{ width: `${quorumProgress}%` }}
              ></div>
            </div>
            <div className="flex justify-between items-center mt-1 text-[10px]">
              <span className="text-on-surface-variant">
                Threshold:{' '}
                {QUORUM_THRESHOLD.toLocaleString(undefined, { maximumFractionDigits: 0 })} SUMR
              </span>
              <span className="text-on-surface font-medium">{quorumProgress.toFixed(1)}%</span>
            </div>
          </div>
        )}
      </div>

      <div className="space-y-3 mt-4">
        {status === 'Active' ? (
          <Link
            href={`/vote/${proposalId}`}
            className="block w-full text-center py-4 bg-primary text-on-primary rounded-xl font-bold text-lg hover:brightness-110 active:scale-[0.98] transition-all shadow-[0_0_20px_rgba(125,211,252,0.2)]"
          >
            Vote on {displayId || proposalId.slice(0, 8)}
          </Link>
        ) : status === 'Succeeded' ? (
          <button
            onClick={handleQueueBaseProposal}
            disabled={isExecuting || isPending}
            className="w-full text-center py-4 bg-primary text-on-primary rounded-xl font-bold text-lg hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50"
          >
            {isExecuting ? 'Queueing...' : 'Queue Proposal'}
          </button>
        ) : status === 'Queued' ? (
          <button
            onClick={handleExecuteBaseProposal}
            disabled={!isBaseReady || isExecuting || isPending}
            className="w-full text-center py-4 bg-primary text-on-primary rounded-xl font-bold text-lg hover:brightness-110 active:scale-[0.98] transition-all disabled:opacity-50"
          >
            {!isBaseReady ? 'In Timelock' : isExecuting ? 'Executing...' : 'Execute'}
          </button>
        ) : status === 'Executed' || status === 'Executed on Hub' ? (
          <div
            className={`w-full text-center py-4 rounded-xl font-bold border ${
              status === 'Executed on Hub'
                ? 'bg-amber-400/10 text-amber-500 border-amber-400/20'
                : 'bg-emerald-400/10 text-emerald-400 border-emerald-400/20'
            }`}
          >
            {status}
          </div>
        ) : null}
      </div>
    </div>
  )
}
